---
name: backport-review
description: Compare downstream backport change requests against upstream OpenStack Gerrit patches. Validates OSPRH ticket presence, Upstream-<release> references per commit, and compares .patch file content.
user-invocable: true
allowed-tools:
  - "WebFetch"
  - "Bash"
context: fork
---

## User Input

```text
$ARGUMENTS
```

The arguments may contain:
- A **change request URL** (required). If not provided, ask for it before proceeding.
- An optional **branch specifier** — either a branch name (e.g. `stable/2025.2`) or a release codename (e.g. `Flamingo`). When provided, use that branch for the upstream patch comparison instead of the oldest branch.

Parse the arguments as follows:
1. Extract the URL (the token starting with `http`).
2. If any remaining token looks like a branch name (`stable/...`, `unmaintained/...`, `master`) or a single word that could be a codename, treat it as the branch specifier.
3. If a **codename** is given (not a branch path), resolve it to a branch name by fetching `https://raw.githubusercontent.com/openstack/releases/refs/heads/master/data/series_status.yaml` and finding the entry whose `name` field matches the codename (case-insensitive). The corresponding `release-id` field gives the YYYY.N version; map it to `stable/<release-id>` (or `unmaintained/<release-id>` if the series status is `unmaintained`). If the codename cannot be resolved, report it to the user and halt.
4. Store the resolved branch (if any) as **`requested_branch`**. When absent, default behaviour applies (oldest branch).

## Goal

Perform a structured backport review:
1. Validate that the change request description contains at least one OSPRH Jira ticket reference.
2. Validate that each commit has at least one `Upstream-<release>: <url>` line in the change request description.
3. For each commit, use its `Change-Id` to locate the equivalent patch on upstream Gerrit (`review.opendev.org`), select the oldest upstream branch that carries that Change-Id, fetch both patches as `.patch` files, and compare them.
4. Produce a concise, structured report.

---

## Step 1 — Set Up Working Directory and Fetch Change Request Data

### 1a. Prepare working directory

Parse the MR number from the URL (e.g. `42` from `.../merge_requests/42`) and set up a clean, MR-scoped working directory:

```bash
MR_ID=42   # parsed from the URL
WORKDIR=/tmp/backport-review/mr${MR_ID}
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
```

All files for this review are written under `${WORKDIR}`. Never reuse files from a previous run.

### 1b. Download downstream patch

```bash
curl -sL "{change_request_url}.patch" -o "${WORKDIR}/downstream.patch"
```

### 1c. Extract fields from the downstream patch

```bash
# List commits (From headers) with line numbers
grep -n "^From " "${WORKDIR}/downstream.patch"

# Extract all Change-Id lines with line numbers
grep -n "^Change-Id:" "${WORKDIR}/downstream.patch"

# Extract all Upstream-* reference lines from commit messages
grep -n "^Upstream-" "${WORKDIR}/downstream.patch"

# Extract OSPRH/OSPCIX ticket references from commit messages
grep -oP '(OSPRH|OSPCIX)-[0-9]+' "${WORKDIR}/downstream.patch" | sort -u
```

### 1d. Extract upstream refs and OSPRH tickets from the MR description

**Do not use WebFetch for this** — it may summarize and drop refs. Use `curl | grep` instead:

```bash
# Fetch raw MR page and extract ALL Upstream-* reference lines
curl -sL "{change_request_url}" \
  | grep -oP '(?<![a-zA-Z])Upstream-[A-Za-z0-9._-]+:\s*https://[^\s<"&]+' \
  | sed 's/&amp;/\&/g' \
  | sort -u > "${WORKDIR}/mr_upstream_refs.txt"
cat "${WORKDIR}/mr_upstream_refs.txt"

# Extract OSPRH/OSPCIX tickets from the MR page
curl -sL "{change_request_url}" | grep -oP '(OSPRH|OSPCIX)-[0-9]+' | sort -u
```

The combined set of `Upstream-*` lines from the `.patch` file and from `${WORKDIR}/mr_upstream_refs.txt` forms the complete upstream refs list. Deduplicate by URL.

Build a per-commit record:
```
commit_N:
  subject: <first line of commit message>
  change_id: I<hex>
```

And a global upstream refs list:
```
upstream_refs:
  - release: master|<year.seq>|<codename>
    url: https://review.opendev.org/c/openstack/<project>/+/<number>
    gerrit_number: <numeric id>
```

---

## Step 2 — Validate Required Metadata

### 2a. OSPRH/OSPCIX ticket check

Verify that at least one `OSPRH-NNNNN` or `OSPCIX-NNNNN` pattern appears anywhere in the change request description or commit messages. If absent, mark as **FAIL**.

### 2b. Upstream reference coverage

For **each** commit in the change request, exactly one of the following must be true:

**Option A — Has upstream:** At least one URL from the complete upstream refs list corresponds to an upstream Gerrit patch with the **same Change-Id** as that commit.

To build the per-commit mapping:
1. For every URL in the complete upstream refs list, parse its Gerrit change number.
2. From the Gerrit API results in Step 3, look up that change number and read its `change_id` field.
3. If that `change_id` matches a downstream commit's `Change-Id`, associate that ref with that commit.
4. A single commit may have **multiple** matching refs (e.g. one for master, one per stable branch). Collect **every** matched ref — do not stop at the first match.
5. Any upstream ref whose Gerrit change number is not found in any commit's Gerrit results is an **unmatched ref** — list it separately in the report as `Unmatched upstream ref: <label>: <url>` so reviewers can investigate.

Record **all** matched refs per commit — they will all appear in the Commit Summary table.

**Option B — Downstream-only:** The commit subject contains the tag `[downstream-only]` (case-insensitive) **and** the change request description explicitly states that the commit is downstream-only (e.g. a sentence or list item explaining why there is no upstream equivalent).

If neither condition is met for a commit, mark it as **FAIL**:
- No upstream ref and no `[downstream-only]` tag → `FAIL (missing upstream ref — add Upstream-<release>: url or mark [downstream-only])`
- Has `[downstream-only]` tag but change request description does not acknowledge it → `FAIL (downstream-only tag in commit but not documented in change request description)`

### 2c. Upstream reference label validation

For **each** `Upstream-<release>: <url>` line (across all commits), validate that the `<release>` label matches the actual branch of the Gerrit change at `<url>`:

1. Parse the Gerrit change number from the URL.
2. From the Gerrit API results in Step 3, look up that change number and read its `branch` field.
3. Resolve the `<release>` label to an expected branch:
   - If the label is a codename (e.g. `Flamingo`, `Gazpacho`), resolve it via `series_status.yaml` to `stable/<release-id>` or `unmaintained/<release-id>`.
   - If the label is already a branch path or `master`, use it directly.
4. Compare the resolved expected branch against the actual `branch` field:
   - **Match** → OK, no warning needed.
   - **Mismatch** → record a **non-critical warning**: `Upstream-<release>: <url> — label implies <expected_branch> but Gerrit change is on <actual_branch>`.

These mismatches are non-blocking (the upstream ref still counts as valid for coverage purposes) but must appear in the report under **Issues Requiring Attention** classified as **NOTABLE**.

---

## Step 3 — Resolve Upstream Patches via Gerrit REST API

For each commit with a `Change-Id`, query the Gerrit REST API to find all upstream patches that share that Change-Id:

```
GET https://review.opendev.org/changes/?q=change:{CHANGE_ID}&o=CURRENT_REVISION&o=CURRENT_COMMIT
```

Use WebFetch for this (the JSON response is small and does not risk summarization). Strip the `)]}'\n` XSSI prefix from the JSON response before parsing.

This returns a list of change objects, each with:
- `id` (numeric change number)
- `branch` (e.g. `master`, `stable/2025.2`, `unmaintained/2023.2`)
- `status` (`MERGED`, `NEW`, `ABANDONED`)
- `subject`

**Filter** to only include changes with status `MERGED` or `NEW` (skip `ABANDONED`).

### Branch ordering (oldest → newest)

Apply this ordering to rank branches, where **oldest** means first to receive the backport chain:

1. `unmaintained/YYYY.N` branches — sort ascending by YYYY, then by N (e.g. `unmaintained/2023.1` < `unmaintained/2023.2` < `unmaintained/2024.1`)
2. `stable/YYYY.N` branches — sort ascending by YYYY, then by N (e.g. `stable/2024.2` < `stable/2025.1` < `stable/2025.2`)
3. `master` — always newest

**Branch selection:**

- If `requested_branch` is set (from the user's arguments), select the upstream change whose `branch` field matches it. If no change exists for that branch, report the mismatch to the user (list the available branches) and halt.
- Otherwise, **select the oldest branch** (lowest rank) as the upstream reference for comparison. If the `Upstream-<release>` lines from Step 1 reference a specific branch, cross-check that it matches.

Record the selected upstream change's numeric ID for patch fetching. When using a user-specified branch, note it clearly in the report (e.g. *"Comparison branch: stable/2025.2 (user-specified; oldest available: stable/2024.2)"*).

---

## Step 4 — Fetch and Compare Patches

### 4a. Fetch upstream patch

For the selected Gerrit change (numeric ID), download and decode the patch into `${WORKDIR}`:

```bash
curl -sL "https://review.opendev.org/changes/{numeric_id}/revisions/current/patch" \
  | base64 -d > "${WORKDIR}/upstream_{numeric_id}.patch"
```

### 4b. Extract the downstream commit's patch section

The full downstream patch is in `${WORKDIR}/downstream.patch`. Extract each commit's section by line range:

```bash
# Find From-header line numbers to determine ranges
grep -n "^From " "${WORKDIR}/downstream.patch"
# e.g. commit 1: lines 1-119, commit 2: lines 120-end
sed -n '1,119p'   "${WORKDIR}/downstream.patch" > "${WORKDIR}/downstream_commit1.patch"
sed -n '120,999999p' "${WORKDIR}/downstream.patch" > "${WORKDIR}/downstream_commit2.patch"
```

### 4c. Compare using shell tools

```bash
# Per-file added/removed line counts for downstream commit N
awk '
  /^diff --git/{ if(file) printf "%s +%d -%d\n", file, add, del; file=""; add=0; del=0 }
  /^\+\+\+ b\//{ file=substr($0,7) }
  /^\+[^\+]/{ add++ }
  /^-[^-]/{ del++ }
  END{ if(file) printf "%s +%d -%d\n", file, add, del }
' "${WORKDIR}/downstream_commitN.patch"

# Per-file added/removed line counts for upstream patch
awk '
  /^diff --git/{ if(file) printf "%s +%d -%d\n", file, add, del; file=""; add=0; del=0 }
  /^\+\+\+ b\//{ file=substr($0,7) }
  /^\+[^\+]/{ add++ }
  /^-[^-]/{ del++ }
  END{ if(file) printf "%s +%d -%d\n", file, add, del }
' "${WORKDIR}/upstream_{numeric_id}.patch"

# Check if a specific identifier exists in each patch
grep -c "def test_some_method" "${WORKDIR}/downstream_commitN.patch"
grep -c "def test_some_method" "${WORKDIR}/upstream_{numeric_id}.patch"

# List all added function/method definitions in each patch
grep "^+.*def " "${WORKDIR}/downstream_commitN.patch"
grep "^+.*def " "${WORKDIR}/upstream_{numeric_id}.patch"

# Direct diff of the two patches (ignoring expected metadata lines)
diff \
  <(grep "^[+-]" "${WORKDIR}/downstream_commitN.patch" | grep -v "^[+-][+-][+-]") \
  <(grep "^[+-]" "${WORKDIR}/upstream_{numeric_id}.patch" | grep -v "^[+-][+-][+-]")
```

Use the per-file line counts from the awk commands to populate the **Files changed** table. For any identifier that appears to differ between the two patches, **always verify with an explicit grep** before reporting it as a difference.

Classify each difference as:
- **EXPECTED**: cherry-pick markers, authorship, date, `Signed-off-by`, `Assisted-By`, trivial rebase offsets in hunk headers.
- **NOTABLE**: added/removed lines not present in the upstream, file paths that differ (may indicate repo structure differences between branches), extra commits not in upstream.
- **CONCERN**: functional logic differences — changed conditionals, different error messages, missing methods, removed tests.

---

## Step 5 — Produce Report

Output a structured Markdown report. Keep it concise; use tables and short bullet points.

```markdown
# Backport Review Report — !{number}

**Change Request:** {url}
**Target branch:** {branch}
**Ticket(s):** {OSPRH-NNNNN / OSPCIX-NNNNN, ...} — PASS / FAIL (none found)

---

## Commit Summary

| # | Subject | Change-Id | Upstream Refs | Upstream Ref Check |
|---|---------|-----------|---------------|--------------------|
| 1 | ... | I... | Upstream-Flamingo: url<br>Upstream-Gazpacho: url | PASS / FAIL |
| 2 | ... | I... | (none) | FAIL — missing |

List **all** `Upstream-<release>:` lines that correspond to each commit (matched by Change-Id). If a ref's label does not match the actual Gerrit branch, append ⚠️ to that ref line (e.g. `Upstream-Gazpacho: url ⚠️ (change is on master)`).

---

## Per-Commit Patch Comparison

### Commit 1 — {subject}

- **Change-Id:** I...
- **Upstream ref(s):** Upstream-2025.2: https://...
- **Comparison branch:** stable/2024.2 (change #{numeric_id}) [oldest available / user-specified]
- **Status:** MERGED / NEW

#### Files changed
| File | Downstream | Upstream | Match? |
|------|-----------|----------|--------|
| watcher/common/cinder_helper.py | (+58 / -16) | (+58 / -16) | YES |
| watcher/tests/... | (+140 / -16) | (+140 / -16) | YES |

#### Differences
- EXPECTED: cherry-pick trailer, date, author
- NOTABLE: (list any, or "None")
- CONCERN: (list any, or "None")

---

## Summary

| Check | Result |
|-------|--------|
| OSPRH ticket present | PASS / FAIL |
| All commits have upstream ref or [downstream-only] | PASS / FAIL |
| Patch content matches upstream | PASS / PARTIAL / FAIL |

**Overall:** PASS / NEEDS ATTENTION / FAIL

### Downstream-only commits
(List any commits marked [downstream-only], even if correctly documented. Always highlight these so reviewers are aware of divergence from upstream.)

### Issues Requiring Attention
(List all NOTABLE and CONCERN items here, including upstream reference label mismatches from Step 2c. Use **NOTABLE** for label mismatches, missing suggested refs, and unmatched refs; use **CONCERN** for functional logic differences. Write "None found — backport looks clean." if there are no items.)
```

---

## Operating Principles

- **Never guess URLs.** Only use URLs provided by the user or retrieved from fetched content.
- **Use curl + shell tools for all .patch file operations.** Never use WebFetch to fetch or analyze `.patch` files — WebFetch summarizes large content and will silently drop methods, functions, or diff hunks. Use `curl` to download patch files and `grep`/`diff`/`sed` for all analysis.
- **Use WebFetch only for small JSON API responses** (Gerrit REST API queries). These are not at risk of losing detail.
- **Never use WebFetch to extract `Upstream-*` refs or OSPRH tickets from the MR page.** Use `curl | grep` instead — WebFetch summarizes HTML pages and will silently drop upstream reference lines.
- **Verify with grep before reporting any difference.** Before classifying a method, function, or identifier as missing from either patch, run an explicit `grep` against the downloaded file. Only report it as absent if `grep` returns no match.
- **Decode base64 Gerrit patches** with `base64 -d` before comparing; do not compare encoded content.
- **Strip XSSI prefix** (`)]}'`) from all Gerrit REST API JSON responses before parsing.
- If a Gerrit query returns no results for a Change-Id, report it as **"upstream not found"** and continue with remaining commits.
- If `curl` cannot retrieve a page (authentication required), report the failure clearly and ask the user to provide the patch content manually.
- Keep diff comparisons focused on **functional changes**; do not flag expected metadata differences as issues.
- If the oldest upstream branch differs from what is listed in the `Upstream-<release>` lines, note the discrepancy but do not fail — it may just mean the reference points to an intermediate backport.
- **Do not report `@@ ... @@` hunk context strings as differences.** Only report differences found in actual `+`/`-` lines.
- **Do not report class names, base classes, or inheritance differences unless they appear explicitly in `+`/`-` lines of the patch.**

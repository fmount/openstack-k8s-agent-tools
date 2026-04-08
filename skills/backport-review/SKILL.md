---
name: backport-review
description: Compare downstream backport change requests against upstream OpenStack Gerrit patches. Validates OSPRH ticket presence, Upstream-<release> references per commit, and compares .patch file content.
user-invocable: true
allowed-tools: ["WebFetch"]
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

## Step 1 — Fetch Change Request Metadata and Commit Messages

Fetch the `.patch` file by appending `.patch` to the change request URL (e.g. `https://example.com/org/repo/-/merge_requests/42.patch`). This returns a multi-patch mbox file with all commits, their full commit messages, and their diffs. Extract from it:

- The full commit message for each commit (bounded by `From ` headers).
- From each commit message:
  - **`Change-Id:`** line (format: `Change-Id: I<hex>`).
  - **`Upstream-<release>:`** lines (format: `Upstream-master: https://...` or `Upstream-2025.2: https://...`). Collect all of them; a commit may reference multiple branches.
  - Any **`OSPRH-NNNNN`** ticket references (may also appear in the change request description).

Also fetch the change request page (`{change_request_url}`) to extract:
- **OSPRH ticket(s)**: scan description and any visible commit messages for patterns `OSPRH-\d+`.
- **All `Upstream-<release>: <url>` lines** present anywhere in the description or comments (not in commit messages). These are the upstream references for the whole change request.

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

### 2a. OSPRH ticket check

Verify that at least one `OSPRH-NNNNN` pattern appears anywhere in the change request description or commit messages. If absent, mark as **FAIL**.

### 2b. Upstream reference coverage

For **each** commit in the change request, exactly one of the following must be true:

**Option A — Has upstream:** At least one URL from the change request description's `Upstream-<release>:` lines corresponds to an upstream Gerrit patch with the **same Change-Id** as that commit. To establish this mapping: when querying Gerrit in Step 3 (which retrieves all branches for each Change-Id), cross-reference the resulting change numbers against the Gerrit numbers parsed from the description's `Upstream-<release>:` URLs.

**Option B — Downstream-only:** The commit subject contains the tag `[downstream-only]` (case-insensitive) **and** the change request description explicitly states that the commit is downstream-only (e.g. a sentence or list item explaining why there is no upstream equivalent).

If neither condition is met for a commit, mark it as **FAIL**:
- No upstream ref and no `[downstream-only]` tag → `FAIL (missing upstream ref — add Upstream-<release>: url or mark [downstream-only])`
- Has `[downstream-only]` tag but change request description does not acknowledge it → `FAIL (downstream-only tag in commit but not documented in change request description)`

---

## Step 3 — Resolve Upstream Patches via Gerrit REST API

For each commit with a `Change-Id`, query the Gerrit REST API to find all upstream patches that share that Change-Id:

```
GET https://review.opendev.org/changes/?q=change:{CHANGE_ID}&o=CURRENT_REVISION&o=CURRENT_COMMIT
```

(Strip the `)]}'\n` XSSI prefix from the JSON response before parsing.)

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

For the selected Gerrit change (numeric ID), fetch the patch:

```
GET https://review.opendev.org/changes/{numeric_id}/revisions/current/patch
```

The response body is a **base64-encoded** mbox patch. Decode it to obtain the raw git patch text.

### 4b. Fetch downstream patch

The downstream commit's patch is already available from the `.patch` file fetched in Step 1. Extract the relevant `From …` section for this commit.

### 4c. Compare

Compare the two patches focusing on:
- **File paths changed**: same files in both? Any extra or missing files in the downstream patch?
- **Added/removed lines** (`+`/`-` in the diff hunks): are the functional changes identical? Note any lines present in one but not the other.
- **Commit message differences**: differences in description, tags, or trailers (expected differences: cherry-pick lines, `Signed-off-by`, `Assisted-By` etc. are normal; flag unexpected functional differences).
- **Context lines** (`@@ ... @@` hunk headers): check if offsets differ significantly, which may indicate the downstream was applied to a different code base version.

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
**OSPRH Ticket(s):** {OSPRH-NNNNN, ...} — PASS / FAIL (none found)

---

## Commit Summary

| # | Subject | Change-Id | Upstream Refs | Upstream Ref Check |
|---|---------|-----------|---------------|--------------------|
| 1 | ... | I... | Upstream-2025.2: url | PASS / FAIL |
| 2 | ... | I... | (none) | FAIL — missing |

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
| watcher/common/cinder_helper.py | +58 / -16 | +58 / -16 | YES |
| watcher/tests/... | +140 / -16 | +140 / -16 | YES |

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
(List any NOTABLE or CONCERN items, or "None found — backport looks clean.")
```

---

## Operating Principles

- **Never guess URLs.** Only use URLs provided by the user or retrieved from fetched content.
- **Decode base64 Gerrit patches** before comparing; do not compare encoded content.
- **Strip XSSI prefix** (`)]}'`) from all Gerrit REST API JSON responses before parsing.
- If a Gerrit query returns no results for a Change-Id, report it as **"upstream not found"** and continue with remaining commits.
- If WebFetch cannot retrieve a page (authentication, JS-only), report the failure clearly and ask the user to provide the patch content manually.
- Keep diff comparisons focused on **functional changes**; do not flag expected metadata differences as issues.
- If the oldest upstream branch differs from what is listed in the `Upstream-<release>` lines, note the discrepancy but do not fail — it may just mean the reference points to an intermediate backport.
- **Do not report `@@ ... @@` hunk context strings (class/function names in diff headers) as differences.** The WebFetch AI that decodes base64 patches may hallucinate or distort those context labels. Only report differences found in actual `+`/`-` lines.
- **Do not report class names, base classes, or inheritance differences unless they appear explicitly in `+`/`-` lines of the patch.** Class definitions visible only in diff context (unchanged lines) must not be treated as changes, and must not be attributed to one side if not confirmed in the actual diff output. Hallucinating class names is a known failure mode — when in doubt, omit rather than guess.

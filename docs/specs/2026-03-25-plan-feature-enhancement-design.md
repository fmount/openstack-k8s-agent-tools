# Plan-Feature Skill Enhancement — Design Spec

**Date:** 2026-03-25
**Scope:** Enhance `/plan-feature` skill with Jira integration, cross-repo analysis, structured planning checklist, and implementation strategies. Add `/task-executor` skill for plan execution.

---

## 1. Overview

The enhanced `plan-feature` skill reads a Jira ticket (via Atlassian MCP) or a local spec file, analyzes the current codebase and cross-references lib-common, peer operators, and dev-docs, then produces a structured implementation plan with strategies and task breakdown. A companion `task-executor` skill executes the plan task-by-task with checkpointing.

Two new agents provide the domain knowledge:
- `agents/plan-feature/AGENT.md` — planning methodology and criteria
- `agents/task-executor/AGENT.md` — execution principles and guidelines

---

## 2. Input Routing

### SKILL.md entry point

```
Input received → parse argument:
  ├─ matches /^[A-Z]+-\d+$/ (e.g., OSPRH-2345) → Jira path
  ├─ matches file path (*.md, exists on disk)   → Spec file path
  └─ no argument                                → ask user which one
```

### Jira path
- Call Atlassian MCP to fetch ticket: summary, description, acceptance criteria, linked tickets, comments.
- On MCP failure: inform user, offer fallback ("Provide a spec file path or paste the ticket content").
- Extract structured context: title, type (story/bug/task), priority, acceptance criteria, linked tickets.

### Spec file path
- Read the markdown file.
- Parse for: problem statement, requirements, acceptance criteria (best-effort, freeform input).

### Output
A normalized **Context Summary** regardless of source, passed to the planning phase.

### Atlassian MCP Integration

**Prerequisite:** Atlassian MCP must be configured in Claude Code settings for Jira integration. The skill works without it via spec file fallback.

**MCP tool usage:** The Atlassian MCP server exposes tools for Jira interaction. The skill uses:
- Fetching a ticket: read the issue by key (e.g., `OSPRH-2345`) to retrieve summary, description, acceptance criteria, comments, linked issues, and issue type (story/bug/task).
- Creating sub-tasks (future): create issues linked as sub-tasks of the parent ticket.

MCP tools are available implicitly when the MCP server is configured — they do not need to be listed in `allowed-tools`. The SKILL.md documents the MCP server as a prerequisite and handles the case where it is not available by catching the tool call failure and offering the spec file fallback.

**Example flow:**
```
1. User invokes: /plan-feature OSPRH-2345
2. SKILL.md detects Jira ticket pattern
3. Agent calls Atlassian MCP to fetch issue OSPRH-2345
4. If MCP fails → "Atlassian MCP not available. Provide a spec file or paste content."
5. If MCP succeeds → normalize into Context Summary
```

---

## 3. Cross-Repo Analysis

Before any planning, the agent analyzes code in this order:

1. **Current operator codebase** — read controllers, API types, webhooks, existing tests. Identify which controllers/CRDs are affected.

2. **Local repo discovery** — check sibling directories or ask user for paths to:
   - lib-common
   - Peer operators (e.g., nova-operator, cinder-operator for similar patterns)
   - dev-docs checkout

3. **Remote fallback** — if repos not available locally, use `gh api` or WebFetch from `github.com/openstack-k8s-operators/`:
   - lib-common: check if a helper already exists
   - dev-docs: fetch relevant convention docs (conditions.md, webhooks.md, observed_generation.md, etc.)
   - Peer operators: search for prior art

4. **Pattern matching** — the agent explicitly answers:
   - Does lib-common already provide a helper for this?
   - Has another operator solved this problem? Which one, and how?
   - Are there dev-docs conventions that govern this area?
   - Is there an existing PR or discussion to reference?

### Output
An **Impact Analysis** section listing affected files, relevant lib-common modules, peer operator references, and applicable dev-docs conventions.

---

## 4. Planning Checklist

After context and analysis, the agent runs a structured checklist. Each item gets a yes/no/N/A assessment with justification:

| Principle | Assessment Criteria |
|-----------|-------------------|
| **API Changes** | New/modified CRD fields? New types in `api/`? Version bump needed? |
| **lib-common Reuse** | Existing helpers to use? Need to contribute a new one upstream? |
| **Code Duplication** | Similar logic in this operator or a peer? Extract or reuse? |
| **Code Style** | gopls modernize patterns to apply? Import grouping, error wrapping, receiver naming? |
| **Webhook Changes** | New validation/defaulting logic? Spec-level Default(), field paths? |
| **Status Conditions** | New conditions required? Severity/reason rules? ObservedGeneration? |
| **EnvTest Tests** | New reconciliation paths needing EnvTest coverage? What to assert? |
| **Kuttl Tests** | Integration-level scenarios needed? New or modified test cases? |
| **RBAC** | New resources accessed? kubebuilder markers needed? |
| **Pre-existing Evidence** | For bugs: logs, error reports, reproduction steps to examine? |
| **Documentation** | dev-docs updates needed? Inline doc changes? |

### Bug-specific additions
- Root cause hypothesis based on logs/description
- Reproduction strategy
- Regression test plan

### Output
A **Planning Checklist** table in the plan document with status per item and notes.

---

## 5. Implementation Strategies & Task Breakdown

### Strategies

The agent proposes 2-3 implementation approaches, each with:
- **Summary** — one-line description
- **Approach** — how it works, which files change, patterns followed
- **Pros/Cons** — trade-offs (complexity, risk, convention alignment, lib-common impact)
- **Recommendation** — agent picks one with reasoning

User must explicitly approve a strategy before task breakdown begins.

### Task Breakdown

Ordered tasks grouped by functional area:

```markdown
## Group 1: API Changes
  - Task 1.1: Add new field to FooSpec
  - Task 1.2: Run make manifests generate
  - Task 1.3: Add webhook validation for new field

## Group 2: Controller Logic
  - Task 2.1: Implement reconciliation for new field
  - Task 2.2: Add status condition handling

## Group 3: Testing
  - Task 3.1: Add EnvTest cases for new path
  - Task 3.2: Add kuttl test scenario
```

Each task includes: description, affected files, dependencies, acceptance criteria.

### Internal vs Jira
- Tasks created internally via TaskCreate for immediate tracking.
- Jira sub-task export is deferred to a future iteration (see Section 11). For now, the plan file on disk is the source of truth.

### Plan file on disk

Written to `$CWD/docs/plans/YYYY-MM-DD-<ticket-or-slug>-plan.md` (relative to the operator repo where the skill is invoked, not the plugin repo) containing:
1. Context Summary
2. Impact Analysis
3. Planning Checklist
4. Implementation Strategies (selected strategy marked)
5. Task Breakdown (status: pending/in-progress/done)

---

## 6. task-executor Skill

### SKILL.md entry point

```
Input received → parse argument:
  ├─ path to plan file  → load and resume
  ├─ no argument        → scan docs/plans/ for recent plans, offer selection
  └─ no plans found     → "No plans available. Run /plan-feature first."
```

### AGENT.md execution principles

1. **Task-by-task** — pick next pending task, execute, mark done. Never skip ahead.
2. **Pre-task validation** — verify dependencies are completed before starting.
3. **Code style enforcement** — follow code-style skill principles (gopls modernize, openstack-k8s-operators conventions, lib-common patterns).
4. **Test-first when applicable** — for new reconciliation paths, write EnvTest first, then implementation.
5. **Checkpoint after each task** — update plan file on disk (mark task done) for resumability.
6. **User confirmation at group boundaries** — pause when finishing a functional group, ask user to review.
7. **No autonomous decisions on ambiguity** — if unclear or multiple valid approaches, stop and ask.

### Error handling

- **Task failure** — if a task fails (build error, test failure), the agent stops, reports the error, and keeps the task as in-progress in the plan file. It does not mark it done or skip to the next task.
- **Corrupted plan file** — if the plan file cannot be parsed (missing structure, invalid markdown), the agent reports the issue and asks the user to fix it or regenerate with `/plan-feature`.
- **Codebase drift** — if the codebase has changed since the plan was created (e.g., files moved, conflicts), the agent detects this during pre-task validation and asks the user whether to adapt the plan or regenerate it.

### Resume flow
- Read plan file, find first task not marked done.
- Show progress summary: "3/8 tasks completed. Next: Task 2.1 — ..."
- Continue execution.

### Plan file progress tracking

```markdown
- [x] Task 1.1: Add new field to FooSpec *(completed)*
- [x] Task 1.2: Run make manifests generate *(completed)*
- [ ] Task 2.1: Implement reconciliation  ← **current**
- [ ] Task 2.2: Add status condition handling
```

---

## 7. SKILL.md Frontmatter

### plan-feature SKILL.md

```yaml
---
name: plan-feature
description: Plan new features or bug fixes for openstack-k8s-operators operators with Jira integration, cross-repo analysis, and structured implementation strategies
user-invocable: true
allowed-tools: ["Bash", "Read", "Write", "Grep", "Glob", "WebFetch", "Agent", "TaskCreate", "TaskUpdate"]
context: fork
---
```

### task-executor SKILL.md

```yaml
---
name: task-executor
description: Execute implementation plans for openstack-k8s-operators operators task-by-task with checkpointing and resumability
user-invocable: true
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob", "Agent", "TaskCreate", "TaskUpdate"]
context: fork
---
```

**Note on `context: fork`:** Both skills use `fork` to isolate their execution context, consistent with all other skills in the project.

---

## 8. AGENT.md Loading Mechanism

Both SKILL.md files must include a mandatory first step, following the `code-review` pattern:

```markdown
## IMPORTANT: First Step

Before doing anything else, you MUST read the agent definition file:

1. Use the Read tool to read `agents/<skill-name>/AGENT.md` from the project root
2. If not found, try `../agents/<skill-name>/AGENT.md` or search with Glob for `**/agents/<skill-name>/AGENT.md`
3. You MUST have read and internalized the AGENT.md content before proceeding
```

---

## 9. AGENT.md Content Outlines

### agents/plan-feature/AGENT.md

```
1. Role Description
   - Senior architect for openstack-k8s-operators feature planning
   - Expertise: controller-runtime, lib-common, Ginkgo/EnvTest, openstack-k8s-operators conventions

2. Input Normalization
   - How to extract structured context from Jira tickets
   - How to parse freeform spec files
   - Normalized Context Summary format

3. Cross-Repo Analysis Procedure
   - Step-by-step: current codebase → local repos → remote fallback
   - What to look for in lib-common (helpers, modules, patterns)
   - What to look for in peer operators (prior art, similar features)
   - What to look for in dev-docs (conventions, guidelines)
   - Pattern matching questions (must answer all before proceeding)

4. Planning Checklist Criteria
   - The full checklist table with expanded guidance per item
   - Bug-specific additions (root cause, reproduction, regression)
   - How to assess each item (what constitutes yes/no/N/A)

5. Strategy Evaluation Framework
   - How to formulate 2-3 approaches
   - Trade-off dimensions: complexity, risk, convention alignment, lib-common impact
   - How to make and justify a recommendation

6. Task Breakdown Guidelines
   - Grouping by functional area
   - Task granularity (one reviewable unit of work per task)
   - Dependency specification
   - Acceptance criteria per task

7. Output Format
   - Plan document structure (5 sections)
   - File naming: $CWD/docs/plans/YYYY-MM-DD-<ticket-or-slug>-plan.md
   - Markdown format for task status tracking

8. Behavioral Rules
   - Read ALL relevant code before proposing anything
   - Never propose reimplementing what lib-common already provides
   - Always present strategies before jumping to task breakdown
   - User must approve strategy before tasks are created
   - Be explicit about what you don't know or couldn't verify
```

### agents/task-executor/AGENT.md

```
1. Role Description
   - Implementation executor for openstack-k8s-operators operators
   - Follows plans produced by plan-feature, strict adherence to task order

2. Plan Loading & Validation
   - How to parse the plan file format
   - How to detect current progress (completed vs pending tasks)
   - How to validate plan file integrity

3. Execution Principles
   - Task-by-task sequential execution
   - Pre-task dependency validation
   - Code style enforcement (gopls modernize, conventions)
   - Test-first for reconciliation paths
   - Checkpointing after each task

4. Code Quality Standards
   - Import grouping (stdlib, external, internal)
   - Error wrapping with context
   - Structured logging (ctrl.LoggerFrom(ctx))
   - Receiver naming conventions
   - lib-common helper usage over custom code

5. Testing Standards
   - EnvTest patterns (Eventually/Gomega, unique namespaces, simulated deps)
   - Kuttl test structure
   - TestVector pattern for validation tests
   - By() statements for complex test steps

6. Checkpoint & Resume Protocol
   - Plan file update format (checkbox markdown)
   - What to record on task completion
   - How to resume from last checkpoint

7. Error Handling
   - Task failure: stop, report, keep in-progress
   - Codebase drift detection
   - Corrupted plan file recovery

8. Group Boundary Protocol
   - Pause at group boundaries for user review
   - What to present at each boundary (summary of changes, files modified)
   - How to proceed after user approval

9. Behavioral Rules
   - Never skip tasks or reorder without user approval
   - Never make autonomous decisions on ambiguous requirements
   - Always run make fmt/vet after code changes
   - Always verify tests pass before marking a task done
```

---

## 10. File Layout

### New files

```
agents/plan-feature/AGENT.md           # Planning methodology & criteria
agents/task-executor/AGENT.md          # Execution principles & guidelines
skills/task-executor/SKILL.md          # Entry point for task execution
.claude/skills/plan-feature/SKILL.md   # Updated copy for auto-discovery
.claude/skills/task-executor/SKILL.md  # New copy for auto-discovery
docs/plans/.gitkeep                    # Directory for generated plans
```

**Note:** The `.claude/skills/` auto-discovery pattern is used by all skills in the project (debug-operator, explain-flow, analyze-logs, code-style, test-operator, plan-feature). The `code-review` skill is currently the only exception — it does not have a `.claude/skills/` copy. This spec follows the majority pattern.

### Modified files

```
skills/plan-feature/SKILL.md           # Rewrite: thin entry point, Jira/spec routing, loads AGENT.md
CLAUDE.md                              # Add task-executor skill, document Atlassian MCP requirement
```

### Unchanged

- `lib/` scripts — no new shell/JS tooling for this iteration
- `scripts/install.sh` — skill auto-discovery handles registration
- Other existing skills and agents

---

## 11. Future Enhancements (Out of Scope)

- **Session management** — persistent session tracking across plan-feature and task-executor invocations
- **Jira sub-task export** — automatic creation of Jira sub-tasks from the task breakdown (the infrastructure is in place via Atlassian MCP, but the UX — user-acknowledged group-by-group export — needs design refinement before shipping)
- **Plan diffing** — detect when a Jira ticket changes after plan creation
- **Multi-operator plans** — plans spanning changes across multiple operator repos

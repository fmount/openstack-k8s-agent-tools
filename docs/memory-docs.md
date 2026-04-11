# Memory, State, and Worktree Architecture

How the plugin persists context across sessions, tracks active work, isolates parallel execution, and resolves dependencies.

## Architecture

```
~/.openstack-k8s-agents-plans/<operator>/
|
+-- MEMORY.md                            Shared project memory
|     read at start of every /feature and /task-executor session
|     updated after planning and after task completion
|
+-- state.json                           Active work tracking
|     tracks worktrees, active tasks, completed plans
|     enables cross-plan dependency resolution
|
+-- 2026-04-11-OSPRH-2345-plan.md        Plan files
+-- 2026-04-11-OSPRH-6789-plan.md        (one per feature/bug)
+-- decisions/                           Decision records (optional)

<operator-repo>/
|
+-- .worktrees/                          Git worktrees (gitignored)
      +-- OSPRH-2345/                    One per active plan
      +-- OSPRH-6789/                    Isolated from main branch
```

## How It All Connects

```
User: /feature OSPRH-2345
    |
    v
+-------------------+
| /feature skill    |
| (orchestrator)    |
+-------------------+
    |
    | 1. Read MEMORY.md for prior context
    | 2. Check for existing plan (resume detection)
    | 3. Dispatch feature agent
    |
    v
+-------------------+
| feature agent     |
| (worker)          |
+-------------------+
    |
    | 4. Cross-repo analysis (informed by MEMORY.md discoveries)
    | 5. Planning checklist
    | 6. Strategies -> user approves
    | 7. Task breakdown with dependencies
    |
    v
+-------------------+
| Write outputs     |
+-------------------+
    |
    +-> Plan file: ~/.openstack-k8s-agents-plans/<operator>/2026-04-11-OSPRH-2345-plan.md
    +-> MEMORY.md: add Active Work entry + discoveries + decisions
    |
    v
User: /task-executor
    |
    v
+-------------------+
| /task-executor    |
| skill             |
+-------------------+
    |
    | 1. Read MEMORY.md
    | 2. Read state.json (check for conflicts)
    | 3. Load plan file
    | 4. Create worktree: .worktrees/OSPRH-2345
    | 5. Register in state.json
    |
    v
+-------------------+
| task-executor     |
| agent (in         |
| worktree)         |
+-------------------+
    |
    | For each task:
    |   a. Check dependencies (intra-plan, cross-plan, external)
    |   b. Execute task
    |   c. Checkpoint: update plan file + state.json
    |   d. At group boundaries: pause for user review
    |
    v
+-------------------+
| Post-             |
| implementation    |
+-------------------+
    |
    +-> Commit (git commit -s -S, human-approved)
    +-> Plan file: add Outcome section
    +-> MEMORY.md: update Active Work, add discoveries
    +-> state.json: move to completed
    +-> Jira: post outcome comment (optional, human-approved)
    +-> Worktree: merge or leave for user review
```

## MEMORY.md

Shared project memory that persists across sessions. All skills read it at start, update it during work.

### Format

```markdown
# glance-operator Memory

## Active Work
- OSPRH-2345: Adding topology support (Task 2.1 in progress, worktree active)
- OSPRH-6789: Fix nil pointer on missing endpoint (plan complete, not started)

## Discoveries
- lib-common common/topology has TopologyHelper -- use it, don't reimplement
- nova-operator implemented topology in PR #423 -- follow same approach
- EnvTest suite takes ~45s, kuttl not configured

## Decisions
- [2026-04-11] OSPRH-2345: follow nova-operator approach (Strategy A)
- [2026-04-11] OSPRH-2345: TopologyRef as pointer field with omitempty

## Blockers
- (none currently)
```

### Which Skills Use It

| Skill | Reads | Writes |
|-------|-------|--------|
| `/feature` | At start (prior context) | After planning (discoveries, decisions, active work) |
| `/task-executor` | At start (prior context, active work) | After each group + on completion (discoveries, status) |
| `/code-review` | Not currently | Not currently |
| `/jira` | Not currently | Not currently |

### Why It Matters

Without MEMORY.md, each session starts from zero. With it:
- The feature agent doesn't re-discover that lib-common already has a helper
- The task-executor knows what decisions were made during planning
- Parallel instances know what each other is working on
- A resumed session picks up context without re-reading the entire codebase

## state.json

Tracks active work across sessions and instances. Enables dependency resolution and prevents duplicate execution.

### Format

```json
{
  "active_tasks": [
    {
      "plan": "2026-04-11-OSPRH-2345-plan.md",
      "task": "2.1",
      "worktree": ".worktrees/OSPRH-2345",
      "branch": "feature/OSPRH-2345",
      "started": "2026-04-11T10:30:00Z"
    }
  ],
  "completed": [
    {
      "plan": "2026-04-10-OSPRH-1000-plan.md",
      "completed": "2026-04-10T18:00:00Z",
      "commit": "abc1234"
    }
  ],
  "discoveries": [
    "lib-common common/topology already has TopologyHelper"
  ]
}
```

## Worktree Isolation

Each plan executes in its own git worktree. This prevents conflicts between parallel instances and keeps the main branch clean.

```
git worktree add -b feature/OSPRH-2345 .worktrees/OSPRH-2345
```

### Parallel Execution

```
Instance 1                          Instance 2
/task-executor OSPRH-2345           /task-executor OSPRH-6789
    |                                   |
    v                                   v
.worktrees/OSPRH-2345               .worktrees/OSPRH-6789
branch: feature/OSPRH-2345         branch: feature/OSPRH-6789
    |                                   |
    | (no file conflicts)               |
    v                                   v
state.json: both registered         state.json: both registered
MEMORY.md: both read/write          MEMORY.md: both read/write
```

### Lifecycle

1. **Create** — `/task-executor` creates worktree before first task
2. **Work** — all file operations happen inside the worktree
3. **Complete** — commit, then ask user: merge now or leave for review?
4. **Cleanup** — on merge: `git worktree remove` + `git branch -d`

## Dependency Resolution

Tasks can declare three types of dependencies:

### Intra-plan

Same plan file. Checked by reading the plan's checkbox state.

```
- [ ] **Task 2.1: Implement reconciliation**
  - **Depends on:** Task 1.1, Task 1.2
```

### Cross-plan

Another plan for the same operator. Checked via state.json and the other plan file.

```
- [ ] **Task 3.1: Update shared CRD types**
  - **Depends on:** OSPRH-6789/Task 1.1
```

### External

A PR in another repository. Checked via `gh pr view`.

```
- [ ] **Task 3.1: Use new TopologyHelper**
  - **External dep:** lib-common PR #789
```

### When Blocked

The task-executor presents options:

```
Task 2.1 is blocked.
  Depends on: Task 1.2 (this plan) -- in progress

Options:
1. Skip to the next unblocked task
2. Proceed anyway (override)
3. Stop and wait
```

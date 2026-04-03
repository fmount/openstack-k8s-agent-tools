---
name: jira
description: Jira integration for openstack-k8s-operators workflows. Reads tickets, validates hierarchy (feature/epic/story), posts outcome comments, and suggests story creation.
user-invocable: true
allowed-tools: ["Bash", "Read", "Write", "Grep"]
context: fork
---

Jira integration skill for openstack-k8s-operators development workflows.

When invoked directly (`/jira OSPRH-2345`), inspect the ticket and report its type, hierarchy, and linked issues. When used as a reference by other skills, follow the rules below.

## Prerequisites

**Human approval is REQUIRED for all write operations.** Never post comments, create stories, update tickets, or modify any Jira resource without presenting the exact content to the human operator and receiving explicit approval first. Read operations (fetching tickets, inspecting hierarchy) do not require approval.

**ALL Jira comments MUST start with `[AI-GENERATED]` prefix.** This is mandatory and non-negotiable. Never post a comment without this prefix.

## Issue Hierarchy

```
Feature / Initiative
  |
  |  Feature
  |  Initiative
  |
  +-- Epic
  |     |
  |     |  Groups stories/tasks/bugs for a single release
  |     |  Must be scoped to a single release
  |     |
  |     +-- Story / Task
  |     |     Actual engineering work, maps to PR(s)
  |     |     Story and Task are interchangeable
  |     |
  |     +-- Bug
  |           Defect (same level as Story, different workflow)
  |
  +-- Epic
        ...
```

### Key Rules

1. **Sub-tasks are NOT used.** Do not create sub-tasks.

2. **Story and Task are interchangeable.** No semantic difference. Teams may have local conventions, but they are not generalizable.

3. **Outcome comments go on the Story/Task/Bug, never on Epic or Feature.** The Story is where engineering work is tracked. The Epic is a container. The Feature is PM-owned.

4. **If the input ticket is a Feature**, find its child Epics. If there's a relevant Epic, find its Stories. Guide the user down to the right Story to work on.

5. **If the input ticket is an Epic with no child Stories**, check if a Spike exists under the Epic instead. If a Spike is found, warn the user: "This Epic has a Spike (<ticket-id>) but no Story. Spikes are timeboxed research — not implementation work. Do you want to continue planning against the Spike, or create a Story first?" If no Spike and no Story, suggest creating a Story before starting implementation.

6. **Bugs follow their own workflow** (New, Refinement, Planning, Backlog, In Progress, Review, Verified, Closed) but are at the same level as Stories for hierarchy purposes.

7. **Bug evaluation — check sibling Stories.** When a Bug has a parent Epic, check the Epic's other children (sibling Stories). Determine if any existing Stories already cover the work needed to fix the bug. If yes, link the Bug to those Stories and note the relationship. If no existing Story covers the fix, suggest creating new Stories under the same Epic for the required work.

8. **Plan breakdown items become separate Stories under the Epic**, not sub-tasks.

## Ticket Inspection

When given a ticket ID:

1. Fetch the ticket via Atlassian MCP
2. Report: type, summary, status, priority, fixVersion
3. Show hierarchy: parent (Feature/Epic), children (Epics/Stories)
4. Flag hierarchy issues per the rules above

Example output:

```
Ticket: OSPRH-2345
Type: Story
Status: In Progress
Priority: Major
fixVersion: 18.0.1
Summary: Add topology support to GlanceAPI
Parent Epic: OSPRH-1000 (Glance operator enhancements)
Linked Stories: OSPRH-2346, OSPRH-2347

Hierarchy: OK — Story linked to Epic
```

## Operations

### Validate Hierarchy

Before any write operation, that must be approved by the human operator, check the hierarchy:

**Story/Task/Bug — OK to work on:**

```
Hierarchy check for OSPRH-2345:
  Type: Story
  Parent Epic: OSPRH-1000
  Status: OK — proceed with planning/implementation
```

**Epic — has a Spike but no Story:**

```
Hierarchy check for OSPRH-1000:
  Type: Epic
  Child Stories: none
  Child Spikes: OSPRH-1050 (Investigate topology approach)
  Status: WARNING — this Epic has a Spike but no Story.
    Spikes are timeboxed research, not implementation work.

Options:
1. Continue planning against the Spike (OSPRH-1050)
2. Create a Story under this Epic first

Which option?
```

**Epic — no Stories and no Spikes:**

```
Hierarchy check for OSPRH-1000:
  Type: Epic
  Child Stories: none
  Status: WARNING — create a Story under this Epic before
    starting implementation.

Suggested Story:
  Project: OSPRH
  Type: Story
  Summary: <suggested based on plan context>
  Epic Link: OSPRH-1000
  fixVersion: <from Epic>
  Description: <suggested based on plan context>

Create this story in Jira, then re-run with the story ID.
```

**Feature — needs navigation down:**

```
Hierarchy check for OSPRH-500:
  Type: Feature
  Child Epics:
    - OSPRH-1000: Glance operator enhancements (In Progress)
    - OSPRH-1001: Glance API v2 migration (Backlog)
  Status: INFO — this is a Feature. Pick the relevant Epic,
    then find or create a Story under it.

Which Epic is this work related to?
```

### Post Outcome Comment

When `/task-executor` completes implementation and the user approves posting:

1. **Validate hierarchy** — target MUST be a Story, Task, or Bug. Refuse to post on Epics or Features.
2. **Compose the comment.** ALL Jira comments MUST start with `[AI-GENERATED]` prefix:

```
[AI-GENERATED] Implementation completed.

Commit: abc1234
Branch: feature/topology-support

Summary:
- Added TopologyRef field to GlanceAPISpec and GlanceSpec
- Reconciler propagates topology constraints to pod specs
- EnvTest coverage for topology reconciliation path

Files changed:
- api/v1beta1/glanceapi_types.go
- controllers/glanceapi_controller.go
- test/functional/glanceapi_controller_test.go
```

1. **Present to the user for approval** before posting
2. Post via Atlassian MCP if approved
3. If MCP is not available, provide the comment text for manual pasting

### Suggest Story Creation

When the plan breakdown has multiple work items and the user wants to track them in Jira:

1. **Do NOT create sub-tasks** — suggest **separate Stories under the same Epic** instead
2. Present the suggested stories:

```
Your plan has 3 groups of work under Epic OSPRH-1000.
These would be separate Stories under the Epic:

1. Story: Add TopologyRef to GlanceAPI types and webhooks
   Epic Link: OSPRH-1000
   fixVersion: 18.0.1

2. Story: Reconcile topology constraints in GlanceAPI controller
   Epic Link: OSPRH-1000
   fixVersion: 18.0.1

3. Story: Add EnvTest coverage for topology reconciliation
   Epic Link: OSPRH-1000
   fixVersion: 18.0.1

Create these Stories in Jira? (I'll provide the fields, you create them)
```

1. Present the fields and let the user create them manually

## Workflow Status Reference

### Story/Task

`Backlog → To Do → In Progress → Closed`

### Bug

`New → Refinement → Planning → Backlog → In Progress → Review → Verified → Closed`

### Epic

`New → Refinement → Backlog → In Progress → Review → Closed`

### Feature

`New → Refinement → Backlog → In Progress → Release Pending → Closed`

## Integration with Other Skills

### /feature uses this skill to

- Read and normalize Jira tickets (input routing)
- Validate hierarchy before planning
- Navigate from Feature → Epic → Story if needed
- Warn if an Epic needs a Story created first

### /task-executor uses this skill to

- Post outcome comments on the Story, never Epic/Feature
- Suggest separate Stories under the Epic for plan breakdown items

### /jira standalone

- Inspect any ticket: `/jira OSPRH-2345`
- Check hierarchy: `/jira OSPRH-1000`

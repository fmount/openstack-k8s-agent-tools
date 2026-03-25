---
name: explain-flow
description: Analyze and explain code flow in openstack-k8s-operators operators with automated parsing and visual diagrams
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
context: fork
---

# Explain Code Flow

This skill provides comprehensive code flow analysis for openstack-k8s-operators operators using automated parsing and visual representation.

## Automated Analysis

When explaining code flow, I will:

1. **Parse Operator Structure**: Automatically discover controllers, reconcilers, and webhooks
2. **Extract Flow Patterns**: Identify reconciliation loops, error handling, and state transitions
3. **Generate Diagrams**: Create visual representations of the code flow
4. **Document Decision Trees**: Map conditional logic and branching paths
5. **Trace Resource Lifecycle**: Show how CRDs move through different states

## Code Parser Features

The skill includes a specialized parser (`code-parser.js`) that analyzes:

- **Controllers**: Reconcile functions and SetupWithManager
- **Flow Steps**: Resource operations (Get, Create, Update, Delete)
- **Error Handling**: Error patterns and retry logic
- **Return Paths**: Different reconciliation outcomes
- **Custom Resources**: CRD definitions and schemas
- **Webhooks**: Validation and defaulting logic
- **Main Function**: Operator initialization and setup

## Analysis Types

### 1. **Reconciler Flow Analysis**

```bash
# Analyze specific controller
node ./lib/code-parser.js /path/to/operator

# Focus on reconcile functions
grep -r "func.*Reconcile" --include="*.go" .
```

### 2. **Resource Lifecycle Mapping**

- Resource creation and initialization
- Status condition updates
- Finalizer processing
- Deletion and cleanup

### 3. **Decision Tree Visualization**

- Conditional logic flow
- Error path handling
- Requeue strategies
- State transitions

### 4. **Interaction Patterns**

- Controller to controller communication
- Webhook integration points
- External API calls
- Event generation

## Visual Output

I will generate:

1. **Flow Diagrams**: Step-by-step execution flow
2. **State Charts**: Resource lifecycle states
3. **Sequence Diagrams**: Inter-component interactions
4. **Call Graphs**: Function relationship maps
5. **Error Flow Charts**: Exception handling paths

## Common Patterns Identified

### Controller Patterns

- `func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request)`
- `client.Get()`, `client.Create()`, `client.Update()`, `client.Delete()`
- `ctrl.Result{RequeueAfter: time.Duration}`
- Status condition management

### Error Handling Patterns

- `if err != nil` blocks
- `return ctrl.Result{}, err`
- Requeue strategies
- Log error patterns

### Resource Patterns

- Finalizer addition/removal
- Owner reference management
- Condition status updates
- Resource validation

## Usage

Invoke `/explain-flow` with:

1. **File/Directory Path**: Target operator code to analyze
2. **Specific Function**: Focus on particular reconciler
3. **Flow Type**: Choose analysis depth (overview, detailed, patterns)

The skill will automatically parse the code, extract flow patterns, and provide visual representations with actionable insights.

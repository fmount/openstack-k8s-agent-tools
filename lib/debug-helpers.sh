#!/bin/bash

# openstack-k8s-operators Operator Debugging Helper Scripts
# Sourced by the debug-operator skill

# Check if KUBECONFIG is set
check_kubeconfig() {
    if [ -z "$KUBECONFIG" ]; then
        echo "❌ KUBECONFIG not set. Please export KUBECONFIG=/path/to/config"
        return 1
    fi
    echo "✅ Using KUBECONFIG: $KUBECONFIG"
    return 0
}

# Get operator pods in common namespaces
get_operator_pods() {
    local namespaces=("openstack" "openstack-operators" "openstack-k8s-operators" "openstack-k8s-operators-operators")

    echo "🔍 Searching for operator pods..."
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null; then
            echo "📋 Namespace: $ns"
            kubectl get pods -n "$ns" -l 'app.kubernetes.io/component=manager' -o wide 2>/dev/null || \
            kubectl get pods -n "$ns" | grep operator 2>/dev/null || \
            echo "  No operator pods found"
            echo
        fi
    done
}

# Check operator deployment status
check_operator_deployment() {
    local operator_name="$1"
    local namespace="${2:-openstack-operators}"

    echo "🏃 Checking deployment: $operator_name in $namespace"

    # Deployment status
    kubectl get deployment "$operator_name" -n "$namespace" -o wide 2>/dev/null || \
    echo "❌ Deployment $operator_name not found in $namespace"

    # ReplicaSet status
    echo "📦 ReplicaSets:"
    kubectl get rs -n "$namespace" -l "app.kubernetes.io/name=$operator_name" 2>/dev/null || \
    echo "  No ReplicaSets found"

    # Pod details
    echo "🔍 Pod details:"
    kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$operator_name" -o wide 2>/dev/null || \
    echo "  No pods found"
}

# Analyze operator logs for common patterns
analyze_operator_logs() {
    local pod_name="$1"
    local namespace="$2"
    local lines="${3:-100}"

    echo "📋 Log analysis for $pod_name in $namespace (last $lines lines)"

    # Get recent logs
    local logs=$(kubectl logs "$pod_name" -n "$namespace" --tail="$lines" 2>/dev/null)

    if [ -z "$logs" ]; then
        echo "❌ Could not retrieve logs"
        return 1
    fi

    # Error patterns
    echo "🚨 Errors and warnings:"
    echo "$logs" | grep -i "error\|warn\|fail\|panic" | tail -10
    echo

    # Reconciliation patterns
    echo "🔄 Reconciliation activity:"
    echo "$logs" | grep -i "reconcil\|controller\|requeue" | tail -5
    echo

    # Resource patterns
    echo "📦 Resource operations:"
    echo "$logs" | grep -i "create\|update\|delete\|patch" | tail -5
    echo
}

# Check custom resource status
check_custom_resources() {
    local crd_pattern="${1:-openstack}"

    echo "📜 Custom Resources matching '$crd_pattern':"

    # List relevant CRDs
    local crds=$(kubectl get crd | grep "$crd_pattern" | awk '{print $1}')

    if [ -z "$crds" ]; then
        echo "❌ No CRDs found matching '$crd_pattern'"
        return 1
    fi

    # Check each CRD
    for crd in $crds; do
        echo "🎯 $crd:"
        kubectl get "$crd" -A --no-headers 2>/dev/null | head -5 || echo "  No instances found"
        echo
    done
}

# Check operator RBAC
check_operator_rbac() {
    local operator_name="$1"
    local namespace="${2:-openstack-operators}"

    echo "🔐 RBAC for $operator_name:"

    # ServiceAccount
    echo "👤 ServiceAccount:"
    kubectl get sa -n "$namespace" | grep "$operator_name" || echo "  Not found"

    # ClusterRole and RoleBindings
    echo "🔑 ClusterRoles:"
    kubectl get clusterrole | grep "$operator_name" || echo "  Not found"

    echo "🔗 ClusterRoleBindings:"
    kubectl get clusterrolebinding | grep "$operator_name" || echo "  Not found"
}

# Get operator events
get_operator_events() {
    local namespace="${1:-openstack-operators}"
    local hours="${2:-1}"

    echo "📅 Recent events in $namespace (last $hours hour(s)):"
    kubectl get events -n "$namespace" \
        --sort-by='.lastTimestamp' \
        --field-selector="type!=Normal" \
        2>/dev/null | tail -20 || echo "  No events found"
}

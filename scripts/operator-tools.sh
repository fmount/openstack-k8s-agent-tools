#!/bin/bash

# openstack-k8s-operators Operator Helper Tools
# Common tasks and utilities for operator development and troubleshooting

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if KUBECONFIG is set
check_kubeconfig() {
    if [ -z "$KUBECONFIG" ]; then
        echo -e "${RED}❌ KUBECONFIG not set${NC}"
        echo "Please set KUBECONFIG: export KUBECONFIG=/path/to/config"
        return 1
    fi
    echo -e "${GREEN}✅ KUBECONFIG: $KUBECONFIG${NC}"
    return 0
}

# Quick operator status check
quick_status() {
    echo -e "${BLUE}🔍 Quick openstack-k8s-operators Status Check${NC}"
    echo "================================"

    check_kubeconfig || return 1

    echo -e "\n${YELLOW}📋 openstack-k8s-operators Namespaces:${NC}"
    kubectl get ns | grep -E "(openstack|openstack-k8s-operators)" || echo "No openstack-k8s-operators namespaces found"

    echo -e "\n${YELLOW}🏃 Operator Pods:${NC}"
    kubectl get pods -A -l 'app.kubernetes.io/component=manager' --no-headers 2>/dev/null | head -10 || echo "No operator pods found"

    echo -e "\n${YELLOW}📜 openstack-k8s-operators CRDs:${NC}"
    kubectl get crd | grep -E "(openstack|openstack-k8s-operators)" | head -5 || echo "No openstack-k8s-operators CRDs found"
}

# Watch operator logs in real-time
watch_logs() {
    local operator_name="${1:-}"
    local namespace="${2:-openstack-operators}"

    if [ -z "$operator_name" ]; then
        echo "Usage: watch_logs <operator-name> [namespace]"
        echo "Available operators:"
        kubectl get pods -A -l 'app.kubernetes.io/component=manager' --no-headers | awk '{print $2}' | sort -u
        return 1
    fi

    check_kubeconfig || return 1

    echo -e "${BLUE}📺 Watching logs for $operator_name in $namespace${NC}"
    echo "Press Ctrl+C to stop..."

    kubectl logs -f "deployment/$operator_name" -n "$namespace" 2>/dev/null || \
    kubectl logs -f -l "app.kubernetes.io/name=$operator_name" -n "$namespace"
}

# Get operator resource usage
resource_usage() {
    local namespace="${1:-openstack-operators}"

    check_kubeconfig || return 1

    echo -e "${BLUE}💾 Resource Usage in $namespace${NC}"
    echo "==================================="

    echo -e "\n${YELLOW}Pod Resource Usage:${NC}"
    kubectl top pods -n "$namespace" 2>/dev/null || echo "Metrics server not available"

    echo -e "\n${YELLOW}Pod Limits and Requests:${NC}"
    kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\t"}{.spec.containers[0].resources.limits.cpu}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}' | column -t
}

# Check operator events
check_events() {
    local namespace="${1:-openstack-operators}"
    local hours="${2:-1}"

    check_kubeconfig || return 1

    echo -e "${BLUE}📅 Events in $namespace (last $hours hour(s))${NC}"
    echo "============================================="

    kubectl get events -n "$namespace" \
        --sort-by='.lastTimestamp' \
        --field-selector="type!=Normal" \
        2>/dev/null | tail -20 || echo "No events found"
}

# Validate operator deployment
validate_deployment() {
    local operator_name="${1:-}"
    local namespace="${2:-openstack-operators}"

    if [ -z "$operator_name" ]; then
        echo "Usage: validate_deployment <operator-name> [namespace]"
        return 1
    fi

    check_kubeconfig || return 1

    echo -e "${BLUE}✅ Validating deployment: $operator_name${NC}"
    echo "=========================================="

    # Check deployment exists
    if ! kubectl get deployment "$operator_name" -n "$namespace" &>/dev/null; then
        echo -e "${RED}❌ Deployment $operator_name not found in $namespace${NC}"
        return 1
    fi

    # Check deployment status
    local ready_replicas=$(kubectl get deployment "$operator_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
    local desired_replicas=$(kubectl get deployment "$operator_name" -n "$namespace" -o jsonpath='{.spec.replicas}')

    echo -e "${YELLOW}📊 Deployment Status:${NC}"
    echo "Ready: $ready_replicas/$desired_replicas"

    if [ "$ready_replicas" = "$desired_replicas" ]; then
        echo -e "${GREEN}✅ Deployment is healthy${NC}"
    else
        echo -e "${RED}❌ Deployment has issues${NC}"
    fi

    # Check pod status
    echo -e "\n${YELLOW}🏃 Pod Status:${NC}"
    kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$operator_name" -o wide

    # Check recent logs for errors
    echo -e "\n${YELLOW}🚨 Recent Errors:${NC}"
    local pod_name=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$operator_name" -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$pod_name" ]; then
        kubectl logs "$pod_name" -n "$namespace" --tail=50 | grep -i "error\|fail\|panic" | tail -5 || echo "No recent errors found"
    fi
}

# Scale operator deployment
scale_operator() {
    local operator_name="${1:-}"
    local replicas="${2:-}"
    local namespace="${3:-openstack-operators}"

    if [ -z "$operator_name" ] || [ -z "$replicas" ]; then
        echo "Usage: scale_operator <operator-name> <replicas> [namespace]"
        return 1
    fi

    check_kubeconfig || return 1

    echo -e "${BLUE}📏 Scaling $operator_name to $replicas replicas${NC}"

    kubectl scale deployment "$operator_name" --replicas="$replicas" -n "$namespace"

    echo "Waiting for scaling to complete..."
    kubectl rollout status deployment/"$operator_name" -n "$namespace" --timeout=60s
}

# Restart operator deployment
restart_operator() {
    local operator_name="${1:-}"
    local namespace="${2:-openstack-operators}"

    if [ -z "$operator_name" ]; then
        echo "Usage: restart_operator <operator-name> [namespace]"
        return 1
    fi

    check_kubeconfig || return 1

    echo -e "${BLUE}🔄 Restarting operator: $operator_name${NC}"

    kubectl rollout restart deployment/"$operator_name" -n "$namespace"
    kubectl rollout status deployment/"$operator_name" -n "$namespace" --timeout=60s
}

# Get operator configuration
get_config() {
    local operator_name="${1:-}"
    local namespace="${2:-openstack-operators}"

    if [ -z "$operator_name" ]; then
        echo "Usage: get_config <operator-name> [namespace]"
        return 1
    fi

    check_kubeconfig || return 1

    echo -e "${BLUE}⚙️  Configuration for $operator_name${NC}"
    echo "===================================="

    # Get deployment config
    echo -e "\n${YELLOW}📋 Deployment Configuration:${NC}"
    kubectl get deployment "$operator_name" -n "$namespace" -o yaml | head -50

    # Get configmaps
    echo -e "\n${YELLOW}🗃️  ConfigMaps:${NC}"
    kubectl get configmap -n "$namespace" | grep "$operator_name" || echo "No ConfigMaps found"

    # Get secrets
    echo -e "\n${YELLOW}🔐 Secrets:${NC}"
    kubectl get secret -n "$namespace" | grep "$operator_name" || echo "No Secrets found"
}

# Check RBAC permissions
check_rbac() {
    local operator_name="${1:-}"
    local namespace="${2:-openstack-operators}"

    if [ -z "$operator_name" ]; then
        echo "Usage: check_rbac <operator-name> [namespace]"
        return 1
    fi

    check_kubeconfig || return 1

    echo -e "${BLUE}🔐 RBAC Configuration for $operator_name${NC}"
    echo "=========================================="

    # Get ServiceAccount
    echo -e "\n${YELLOW}👤 ServiceAccount:${NC}"
    kubectl get sa -n "$namespace" | grep "$operator_name" || echo "No ServiceAccount found"

    # Get ClusterRole
    echo -e "\n${YELLOW}🔑 ClusterRoles:${NC}"
    kubectl get clusterrole | grep "$operator_name" || echo "No ClusterRoles found"

    # Get ClusterRoleBinding
    echo -e "\n${YELLOW}🔗 ClusterRoleBindings:${NC}"
    kubectl get clusterrolebinding | grep "$operator_name" || echo "No ClusterRoleBindings found"

    # Get RoleBinding
    echo -e "\n${YELLOW}🔗 RoleBindings:${NC}"
    kubectl get rolebinding -n "$namespace" | grep "$operator_name" || echo "No RoleBindings found"
}

# Debug operator issues
debug_operator() {
    local operator_name="${1:-}"
    local namespace="${2:-openstack-operators}"

    if [ -z "$operator_name" ]; then
        echo "Usage: debug_operator <operator-name> [namespace]"
        echo "This runs a comprehensive debug check"
        return 1
    fi

    echo -e "${BLUE}🔍 Comprehensive Debug: $operator_name${NC}"
    echo "========================================"

    validate_deployment "$operator_name" "$namespace"
    echo
    resource_usage "$namespace"
    echo
    check_events "$namespace"
    echo
    check_rbac "$operator_name" "$namespace"
}

# Show help
show_help() {
    echo -e "${BLUE}🛠️  openstack-k8s-operators Operator Tools${NC}"
    echo "========================"
    echo
    echo "Available commands:"
    echo "  quick_status                              - Quick status overview"
    echo "  watch_logs <operator> [namespace]         - Watch operator logs"
    echo "  resource_usage [namespace]                - Show resource usage"
    echo "  check_events [namespace] [hours]          - Show recent events"
    echo "  validate_deployment <operator> [namespace] - Validate deployment"
    echo "  scale_operator <operator> <replicas> [ns] - Scale operator"
    echo "  restart_operator <operator> [namespace]   - Restart operator"
    echo "  get_config <operator> [namespace]         - Show configuration"
    echo "  check_rbac <operator> [namespace]         - Check RBAC setup"
    echo "  debug_operator <operator> [namespace]     - Comprehensive debug"
    echo
    echo "Examples:"
    echo "  ./operator-tools.sh quick_status"
    echo "  ./operator-tools.sh watch_logs nova-operator"
    echo "  ./operator-tools.sh debug_operator heat-operator openstack"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "quick_status")
            quick_status
            ;;
        "watch_logs")
            watch_logs "$2" "$3"
            ;;
        "resource_usage")
            resource_usage "$2"
            ;;
        "check_events")
            check_events "$2" "$3"
            ;;
        "validate_deployment")
            validate_deployment "$2" "$3"
            ;;
        "scale_operator")
            scale_operator "$2" "$3" "$4"
            ;;
        "restart_operator")
            restart_operator "$2" "$3"
            ;;
        "get_config")
            get_config "$2" "$3"
            ;;
        "check_rbac")
            check_rbac "$2" "$3"
            ;;
        "debug_operator")
            debug_operator "$2" "$3"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

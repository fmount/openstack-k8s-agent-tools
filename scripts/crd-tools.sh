#!/bin/bash

# openstack-k8s-operators CRD Analysis Tools
# Tools for analyzing and troubleshooting Custom Resource Definitions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# List all openstack-k8s-operators CRDs
list_crds() {
    local pattern="${1:-openstack}"

    echo -e "${BLUE}📜 openstack-k8s-operators Custom Resource Definitions${NC}"
    echo "======================================"

    echo -e "\n${YELLOW}CRDs matching '$pattern':${NC}"
    kubectl get crd | grep "$pattern" | awk '{print $1, $2, $3}' | column -t
}

# Analyze specific CRD
analyze_crd() {
    local crd_name="$1"

    if [ -z "$crd_name" ]; then
        echo "Usage: analyze_crd <crd-name>"
        echo "Available CRDs:"
        kubectl get crd | grep openstack | awk '{print $1}'
        return 1
    fi

    echo -e "${BLUE}🔍 Analyzing CRD: $crd_name${NC}"
    echo "==============================="

    # Basic info
    echo -e "\n${YELLOW}📋 Basic Information:${NC}"
    kubectl get crd "$crd_name" -o custom-columns="NAME:.metadata.name,GROUP:.spec.group,KIND:.spec.names.kind,VERSION:.spec.versions[0].name" --no-headers

    # Versions
    echo -e "\n${YELLOW}📊 Supported Versions:${NC}"
    kubectl get crd "$crd_name" -o jsonpath='{.spec.versions[*].name}' | tr ' ' '\n'

    # Schema info
    echo -e "\n${YELLOW}🗂️  Schema Properties:${NC}"
    local schema=$(kubectl get crd "$crd_name" -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties}' 2>/dev/null)
    if [ -n "$schema" ]; then
        echo "$schema" | jq -r 'keys[]' 2>/dev/null | head -10 || echo "Schema information not available"
    else
        echo "Schema information not available"
    fi
}

# List instances of a CRD
list_instances() {
    local crd_name="$1"
    local namespace="${2:---all-namespaces}"

    if [ -z "$crd_name" ]; then
        echo "Usage: list_instances <crd-name> [namespace|--all-namespaces]"
        return 1
    fi

    # Extract resource name from CRD
    local resource_name=$(kubectl get crd "$crd_name" -o jsonpath='{.spec.names.plural}' 2>/dev/null)

    if [ -z "$resource_name" ]; then
        echo "CRD $crd_name not found"
        return 1
    fi

    echo -e "${BLUE}📦 Instances of $crd_name${NC}"
    echo "=========================="

    if [ "$namespace" = "--all-namespaces" ]; then
        kubectl get "$resource_name" -A -o wide 2>/dev/null || echo "No instances found"
    else
        kubectl get "$resource_name" -n "$namespace" -o wide 2>/dev/null || echo "No instances found in $namespace"
    fi
}

# Check instance status
check_instance_status() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="$3"

    if [ -z "$resource_type" ] || [ -z "$resource_name" ]; then
        echo "Usage: check_instance_status <resource-type> <resource-name> [namespace]"
        return 1
    fi

    local ns_flag=""
    if [ -n "$namespace" ]; then
        ns_flag="-n $namespace"
    fi

    echo -e "${BLUE}📊 Status for $resource_type/$resource_name${NC}"
    echo "========================================="

    # Get resource details
    echo -e "\n${YELLOW}📋 Resource Details:${NC}"
    kubectl get "$resource_type" "$resource_name" $ns_flag -o wide 2>/dev/null || echo "Resource not found"

    # Get status conditions
    echo -e "\n${YELLOW}🔍 Status Conditions:${NC}"
    kubectl get "$resource_type" "$resource_name" $ns_flag -o jsonpath='{.status.conditions}' 2>/dev/null | jq '.' 2>/dev/null || echo "No status conditions"

    # Get events
    echo -e "\n${YELLOW}📅 Related Events:${NC}"
    kubectl get events $ns_flag --field-selector involvedObject.name="$resource_name" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No events found"
}

# Validate CRD instances
validate_instances() {
    local crd_name="$1"

    if [ -z "$crd_name" ]; then
        echo "Usage: validate_instances <crd-name>"
        return 1
    fi

    local resource_name=$(kubectl get crd "$crd_name" -o jsonpath='{.spec.names.plural}' 2>/dev/null)

    if [ -z "$resource_name" ]; then
        echo "CRD $crd_name not found"
        return 1
    fi

    echo -e "${BLUE}✅ Validating instances of $crd_name${NC}"
    echo "======================================"

    # Get all instances
    local instances=$(kubectl get "$resource_name" -A --no-headers 2>/dev/null | awk '{print $2 ":" $1}')

    if [ -z "$instances" ]; then
        echo "No instances found"
        return 0
    fi

    # Check each instance
    echo "$instances" | while IFS=: read -r name namespace; do
        echo -e "\n${YELLOW}Checking $namespace/$name:${NC}"

        # Check if ready
        local ready=$(kubectl get "$resource_name" "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$ready" = "True" ]; then
            echo -e "${GREEN}  ✅ Ready${NC}"
        else
            echo -e "${RED}  ❌ Not Ready${NC}"
            # Show reason if available
            local reason=$(kubectl get "$resource_name" "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
            [ -n "$reason" ] && echo -e "     Reason: $reason"
        fi

        # Check for errors in status
        local error_conditions=$(kubectl get "$resource_name" "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.status=="False")]}' 2>/dev/null)
        if [ -n "$error_conditions" ] && [ "$error_conditions" != "null" ]; then
            echo -e "${RED}  ⚠️  Has error conditions${NC}"
        fi
    done
}

# Show CRD dependencies
show_dependencies() {
    local crd_name="$1"

    if [ -z "$crd_name" ]; then
        echo "Usage: show_dependencies <crd-name>"
        return 1
    fi

    echo -e "${BLUE}🔗 Dependencies for $crd_name${NC}"
    echo "=============================="

    # Look for owner references in instances
    local resource_name=$(kubectl get crd "$crd_name" -o jsonpath='{.spec.names.plural}' 2>/dev/null)

    if [ -z "$resource_name" ]; then
        echo "CRD $crd_name not found"
        return 1
    fi

    echo -e "\n${YELLOW}Owner References:${NC}"
    kubectl get "$resource_name" -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" -> "}{.metadata.ownerReferences[*].kind}{" "}{.metadata.ownerReferences[*].name}{"\n"}{end}' 2>/dev/null | grep -v "^ -> $" || echo "No owner references found"

    # Look for finalizers
    echo -e "\n${YELLOW}Finalizers:${NC}"
    kubectl get "$resource_name" -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{": "}{.metadata.finalizers}{"\n"}{end}' 2>/dev/null | grep -v ": $" || echo "No finalizers found"
}

# Monitor CRD changes
monitor_changes() {
    local resource_type="$1"
    local namespace="${2:---all-namespaces}"

    if [ -z "$resource_type" ]; then
        echo "Usage: monitor_changes <resource-type> [namespace|--all-namespaces]"
        return 1
    fi

    echo -e "${BLUE}👁️  Monitoring changes to $resource_type${NC}"
    echo "================================="
    echo "Press Ctrl+C to stop..."

    if [ "$namespace" = "--all-namespaces" ]; then
        kubectl get "$resource_type" -A --watch
    else
        kubectl get "$resource_type" -n "$namespace" --watch
    fi
}

# Show CRD usage statistics
show_stats() {
    local pattern="${1:-openstack}"

    echo -e "${BLUE}📊 CRD Usage Statistics${NC}"
    echo "========================"

    local crds=$(kubectl get crd | grep "$pattern" | awk '{print $1}')

    if [ -z "$crds" ]; then
        echo "No CRDs found matching '$pattern'"
        return 1
    fi

    echo -e "\n${YELLOW}Resource Type                    Count${NC}"
    echo "==========================================="

    for crd in $crds; do
        local resource_name=$(kubectl get crd "$crd" -o jsonpath='{.spec.names.plural}' 2>/dev/null)
        local count=$(kubectl get "$resource_name" -A --no-headers 2>/dev/null | wc -l)
        printf "%-30s %5s\n" "$resource_name" "$count"
    done
}

# Main help function
show_help() {
    echo -e "${BLUE}🗂️  openstack-k8s-operators CRD Tools${NC}"
    echo "==================="
    echo
    echo "Available commands:"
    echo "  list_crds [pattern]                      - List CRDs (default: openstack)"
    echo "  analyze_crd <crd-name>                   - Analyze specific CRD"
    echo "  list_instances <crd-name> [namespace]    - List CRD instances"
    echo "  check_instance_status <type> <name> [ns] - Check instance status"
    echo "  validate_instances <crd-name>            - Validate all instances"
    echo "  show_dependencies <crd-name>             - Show dependencies"
    echo "  monitor_changes <resource-type> [ns]     - Monitor resource changes"
    echo "  show_stats [pattern]                     - Usage statistics"
    echo
    echo "Examples:"
    echo "  ./crd-tools.sh list_crds"
    echo "  ./crd-tools.sh analyze_crd openstackcontrolplanes.core.openstack.org"
    echo "  ./crd-tools.sh list_instances openstackcontrolplanes.core.openstack.org"
    echo "  ./crd-tools.sh validate_instances openstackcontrolplanes.core.openstack.org"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "list_crds")
            list_crds "$2"
            ;;
        "analyze_crd")
            analyze_crd "$2"
            ;;
        "list_instances")
            list_instances "$2" "$3"
            ;;
        "check_instance_status")
            check_instance_status "$2" "$3" "$4"
            ;;
        "validate_instances")
            validate_instances "$2"
            ;;
        "show_dependencies")
            show_dependencies "$2"
            ;;
        "monitor_changes")
            monitor_changes "$2" "$3"
            ;;
        "show_stats")
            show_stats "$2"
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

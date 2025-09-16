#!/bin/bash

# Post-Deployment Verification Script for AKS
# This script performs comprehensive checks to verify the deployment is working correctly

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_LABEL="app=fastapi-app"
DEPLOYMENT_NAME="fastapi-app"
SERVICE_NAME="fastapi-loadbalancer"
PVC_NAME="fastapi-pvc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}===========================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to check if kubectl is configured
check_kubectl() {
    print_header "CHECKING KUBECTL CONFIGURATION"
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cluster is not accessible"
        return 1
    fi
    
    local cluster_name=$(kubectl config current-context 2>/dev/null || echo "unknown")
    print_success "Connected to cluster: $cluster_name"
    echo
    return 0
}

# Function to check AKS cluster status
check_cluster_status() {
    print_header "CHECKING AKS CLUSTER STATUS"
    
    print_status "Cluster information:"
    kubectl cluster-info
    echo
    
    print_status "Node status:"
    kubectl get nodes -o wide
    echo
    
    print_status "Cluster resource usage:"
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
    echo
    
    return 0
}

# Function to verify Kubernetes resources
check_kubernetes_resources() {
    print_header "CHECKING KUBERNETES RESOURCES"
    
    # Check deployment
    print_status "Checking deployment status..."
    if kubectl get deployment $DEPLOYMENT_NAME &> /dev/null; then
        local ready_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            print_success "Deployment $DEPLOYMENT_NAME is ready ($ready_replicas/$desired_replicas replicas)"
        else
            print_error "Deployment $DEPLOYMENT_NAME is not ready ($ready_replicas/$desired_replicas replicas)"
        fi
        
        kubectl get deployment $DEPLOYMENT_NAME
    else
        print_error "Deployment $DEPLOYMENT_NAME not found"
    fi
    echo
    
    # Check pods
    print_status "Checking pod status..."
    if kubectl get pods -l $APP_LABEL &> /dev/null; then
        local total_pods=$(kubectl get pods -l $APP_LABEL --no-headers | wc -l)
        local running_pods=$(kubectl get pods -l $APP_LABEL --no-headers | grep -c "Running" || echo "0")
        local ready_pods=$(kubectl get pods -l $APP_LABEL -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
        
        if [ "$running_pods" = "$total_pods" ] && [ "$ready_pods" = "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            print_success "All pods are running and ready ($ready_pods/$total_pods)"
        else
            print_error "Not all pods are ready (Running: $running_pods/$total_pods, Ready: $ready_pods/$total_pods)"
        fi
        
        kubectl get pods -l $APP_LABEL -o wide
    else
        print_error "No pods found with label $APP_LABEL"
    fi
    echo
    
    # Check services
    print_status "Checking service status..."
    if kubectl get service $SERVICE_NAME &> /dev/null; then
        local external_ip=$(kubectl get service $SERVICE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
            print_success "LoadBalancer service has external IP: $external_ip"
        else
            print_warning "LoadBalancer service does not have an external IP yet"
        fi
        
        kubectl get service $SERVICE_NAME
    else
        print_error "Service $SERVICE_NAME not found"
    fi
    echo
    
    # Check PVC
    print_status "Checking persistent volume claim..."
    if kubectl get pvc $PVC_NAME &> /dev/null; then
        local pvc_status=$(kubectl get pvc $PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        if [ "$pvc_status" = "Bound" ]; then
            print_success "PVC $PVC_NAME is bound"
        else
            print_error "PVC $PVC_NAME is not bound (Status: $pvc_status)"
        fi
        
        kubectl get pvc $PVC_NAME
    else
        print_error "PVC $PVC_NAME not found"
    fi
    echo
    
    return 0
}

# Function to check persistent volume mounting
check_persistent_volume() {
    print_header "CHECKING PERSISTENT VOLUME MOUNTING"
    
    local pod_name=$(kubectl get pods -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "No pods found to check volume mounting"
        return 1
    fi
    
    print_status "Checking volume mount in pod: $pod_name"
    
    # Check if /data directory exists and is writable
    if kubectl exec $pod_name -- test -d /data 2>/dev/null; then
        print_success "Volume mount point /data exists"
        
        if kubectl exec $pod_name -- test -w /data 2>/dev/null; then
            print_success "Volume mount point /data is writable"
            
            # Test write operation
            if kubectl exec $pod_name -- sh -c 'echo "test" > /data/test_file.txt' 2>/dev/null; then
                print_success "Successfully wrote test file to persistent volume"
                kubectl exec $pod_name -- rm -f /data/test_file.txt 2>/dev/null
            else
                print_error "Failed to write to persistent volume"
            fi
        else
            print_error "Volume mount point /data is not writable"
        fi
    else
        print_error "Volume mount point /data does not exist"
    fi
    
    # Show mounted volumes
    print_status "Mounted volumes in pod:"
    kubectl exec $pod_name -- df -h | grep -E "(Filesystem|/data)" || print_warning "Could not retrieve volume information"
    echo
    
    return 0
}

# Function to test application endpoints
test_application_endpoints() {
    print_header "TESTING APPLICATION ENDPOINTS"
    
    local external_ip=$(kubectl get service $SERVICE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$external_ip" ] || [ "$external_ip" = "null" ]; then
        print_error "No external IP available for testing"
        return 1
    fi
    
    print_status "Testing endpoints on external IP: $external_ip"
    
    # Test health endpoint
    print_status "Testing /health endpoint..."
    if curl -f -s "http://$external_ip/health" > /dev/null 2>&1; then
        print_success "Health endpoint is responding"
        local health_response=$(curl -s "http://$external_ip/health" | jq -r '.status' 2>/dev/null || echo "unknown")
        print_status "Health status: $health_response"
    else
        print_error "Health endpoint is not responding"
    fi
    
    # Test ready endpoint
    print_status "Testing /ready endpoint..."
    if curl -f -s "http://$external_ip/ready" > /dev/null 2>&1; then
        print_success "Readiness endpoint is responding"
        local ready_response=$(curl -s "http://$external_ip/ready" | jq -r '.status' 2>/dev/null || echo "unknown")
        print_status "Ready status: $ready_response"
    else
        print_error "Readiness endpoint is not responding"
    fi
    
    # Test root endpoint
    print_status "Testing root endpoint..."
    if curl -f -s "http://$external_ip/" > /dev/null 2>&1; then
        print_success "Root endpoint is responding"
    else
        print_error "Root endpoint is not responding"
    fi
    
    # Test file operations
    print_status "Testing file operations..."
    local test_content="This is a test file created by the verification script"
    local test_response=$(curl -s -X POST "http://$external_ip/write-file" \
        -H "Content-Type: application/json" \
        -d "{\"content\":\"$test_content\",\"filename\":\"verification_test.txt\"}" 2>/dev/null)
    
    if echo "$test_response" | grep -q "File written successfully" 2>/dev/null; then
        print_success "File write operation successful"
        
        # Test file listing
        if curl -f -s "http://$external_ip/list-files" > /dev/null 2>&1; then
            print_success "File listing endpoint is working"
        else
            print_warning "File listing endpoint might not be working"
        fi
    else
        print_error "File write operation failed"
    fi
    
    echo
    return 0
}

# Function to show application logs
show_application_logs() {
    print_header "APPLICATION LOGS (Last 20 lines)"
    
    kubectl logs deployment/$DEPLOYMENT_NAME --tail=20
    echo
}

# Function to display access information
display_access_info() {
    print_header "APPLICATION ACCESS INFORMATION"
    
    local external_ip=$(kubectl get service $SERVICE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        echo "🌐 Application URL:    http://$external_ip"
        echo "❤️  Health Check:      http://$external_ip/health"
        echo "✅ Readiness Check:    http://$external_ip/ready"
        echo "📖 API Documentation: http://$external_ip/docs"
        echo "📝 Write File:         http://$external_ip/write-file (POST)"
        echo "📋 List Files:         http://$external_ip/list-files"
        echo "📖 Read File:          http://$external_ip/read-file/{filename}"
        echo "🗄️  Initialize DWH:     http://$external_ip/init-dwh (POST)"
        echo "🔍 Analytics Query:    http://$external_ip/query"
    else
        print_warning "External IP not available yet. Check service status:"
        kubectl get service $SERVICE_NAME
    fi
    
    echo
}

# Function to show troubleshooting commands
show_troubleshooting_commands() {
    print_header "TROUBLESHOOTING COMMANDS"
    
    echo "If you encounter issues, use these commands for debugging:"
    echo
    echo "# Check deployment details"
    echo "kubectl describe deployment $DEPLOYMENT_NAME"
    echo
    echo "# Check pod details"
    echo "kubectl describe pods -l $APP_LABEL"
    echo
    echo "# Check service details"
    echo "kubectl describe service $SERVICE_NAME"
    echo
    echo "# Check PVC details"
    echo "kubectl describe pvc $PVC_NAME"
    echo
    echo "# View recent logs"
    echo "kubectl logs -f deployment/$DEPLOYMENT_NAME"
    echo
    echo "# Execute shell in pod"
    echo "kubectl exec -it \$(kubectl get pods -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}') -- /bin/bash"
    echo
    echo "# Check events"
    echo "kubectl get events --sort-by=.metadata.creationTimestamp"
    echo
}

# Function to run all checks
run_verification() {
    local all_passed=true
    
    print_header "AZURE KUBERNETES SERVICE DEPLOYMENT VERIFICATION"
    print_status "Starting comprehensive deployment verification..."
    echo
    
    # Run all checks
    check_kubectl || all_passed=false
    check_cluster_status || all_passed=false
    check_kubernetes_resources || all_passed=false
    check_persistent_volume || all_passed=false
    test_application_endpoints || all_passed=false
    show_application_logs
    display_access_info
    
    if [ "$all_passed" = true ]; then
        print_header "✅ ALL CHECKS PASSED!"
        print_success "Your FastAPI application is successfully deployed and running on AKS!"
    else
        print_header "⚠️  SOME CHECKS FAILED"
        print_warning "Some verification checks failed. Please review the output above."
        show_troubleshooting_commands
        return 1
    fi
    
    return 0
}

# Function to show help
show_help() {
    echo "AKS Deployment Verification Script"
    echo
    echo "This script performs comprehensive verification of the FastAPI application deployment on AKS."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --quick          Run only basic checks (skip endpoint testing)"
    echo "  --logs-only      Show only application logs"
    echo "  --access-info    Show only access information"
    echo "  --troubleshoot   Show troubleshooting commands"
    echo "  --help          Show this help message"
    echo
    echo "The script checks:"
    echo "  - Kubectl configuration and cluster connectivity"
    echo "  - AKS cluster status and nodes"
    echo "  - Kubernetes resources (deployment, pods, services, PVC)"
    echo "  - Persistent volume mounting and accessibility"
    echo "  - Application endpoint functionality"
    echo "  - Application logs and access information"
}

# Main execution
main() {
    case ${1:-""} in
        --quick)
            check_kubectl
            check_kubernetes_resources
            display_access_info
            ;;
        --logs-only)
            show_application_logs
            ;;
        --access-info)
            display_access_info
            ;;
        --troubleshoot)
            show_troubleshooting_commands
            ;;
        --help|-h)
            show_help
            ;;
        "")
            run_verification
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
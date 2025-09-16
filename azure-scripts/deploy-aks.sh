#!/bin/bash

# Comprehensive AKS Deployment Script
# This script automates the complete deployment workflow for the FastAPI application on AKS

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="fastapi-app"
IMAGE_TAG="latest"

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    local missing_tools=()
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        missing_tools+=("Azure CLI")
    else
        print_status "✓ Azure CLI found"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("Docker")
    else
        print_status "✓ Docker found"
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("Terraform")
    else
        print_status "✓ Terraform found"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    else
        print_status "✓ kubectl found"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    else
        print_status "✓ jq found"
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo
        echo "Please install the missing tools:"
        echo "- Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        echo "- Docker: https://docs.docker.com/get-docker/"
        echo "- Terraform: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        echo "- kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "- jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi
    
    # Check Azure CLI login
    print_status "Checking Azure CLI authentication..."
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    # Check Docker daemon
    print_status "Checking Docker daemon..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "All prerequisites satisfied!"
    echo
}

# Function to build and push Docker image
build_and_push_image() {
    print_header "BUILDING AND PUSHING DOCKER IMAGE"
    
    cd "$SCRIPT_DIR"
    
    print_status "Executing docker-build-push.sh..."
    if [ -f "docker-build-push.sh" ]; then
        chmod +x docker-build-push.sh
        if ./docker-build-push.sh "$IMAGE_TAG" "$PROJECT_DIR"; then
            print_success "Docker image built and pushed successfully!"
        else
            print_error "Failed to build and push Docker image"
            exit 1
        fi
    else
        print_error "docker-build-push.sh script not found"
        exit 1
    fi
    
    echo
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    print_header "DEPLOYING AZURE INFRASTRUCTURE WITH TERRAFORM"
    
    cd "$SCRIPT_DIR"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    if terraform init; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    # Plan deployment
    print_status "Creating Terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan created successfully"
    else
        print_error "Terraform planning failed"
        exit 1
    fi
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    if terraform apply -auto-approve tfplan; then
        print_success "Infrastructure deployed successfully!"
    else
        print_error "Terraform apply failed"
        exit 1
    fi
    
    # Clean up plan file
    rm -f tfplan
    
    echo
}

# Function to configure kubectl
configure_kubectl() {
    print_header "CONFIGURING KUBECTL ACCESS"
    
    cd "$SCRIPT_DIR"
    
    # Get cluster details from Terraform outputs
    print_status "Retrieving cluster information from Terraform..."
    
    local resource_group
    local cluster_name
    
    if command -v terraform &> /dev/null; then
        resource_group=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
        cluster_name=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
    fi
    
    if [ -z "$resource_group" ] || [ -z "$cluster_name" ]; then
        print_warning "Could not get cluster details from terraform output, trying state file..."
        if [ -f "terraform.tfstate" ]; then
            resource_group=$(jq -r '.outputs.resource_group_name.value // empty' terraform.tfstate)
            cluster_name=$(jq -r '.outputs.aks_cluster_name.value // empty' terraform.tfstate)
        fi
    fi
    
    if [ -z "$resource_group" ] || [ -z "$cluster_name" ]; then
        print_error "Could not retrieve cluster information. Please check Terraform deployment."
        exit 1
    fi
    
    print_status "Resource Group: $resource_group"
    print_status "AKS Cluster: $cluster_name"
    
    # Configure kubectl
    print_status "Configuring kubectl credentials..."
    if az aks get-credentials --resource-group "$resource_group" --name "$cluster_name" --overwrite-existing; then
        print_success "kubectl configured successfully!"
    else
        print_error "Failed to configure kubectl"
        exit 1
    fi
    
    # Verify connection
    print_status "Verifying cluster connection..."
    if kubectl cluster-info &> /dev/null; then
        print_success "Successfully connected to AKS cluster!"
    else
        print_error "Failed to connect to AKS cluster"
        exit 1
    fi
    
    echo
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    print_header "WAITING FOR APPLICATION DEPLOYMENT"
    
    print_status "Waiting for FastAPI deployment to be ready..."
    
    # Wait for deployment to be available (max 10 minutes)
    if kubectl wait --for=condition=available --timeout=600s deployment/fastapi-app; then
        print_success "Deployment is ready!"
    else
        print_error "Deployment did not become ready within 10 minutes"
        print_status "Checking pod status for troubleshooting..."
        kubectl get pods -l app=fastapi-app
        kubectl describe pods -l app=fastapi-app
        exit 1
    fi
    
    # Wait for pods to be running
    print_status "Waiting for pods to be running..."
    sleep 10
    
    local pods_ready=false
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ] && [ "$pods_ready" = false ]; do
        local ready_pods=$(kubectl get pods -l app=fastapi-app -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
        local total_pods=$(kubectl get pods -l app=fastapi-app --no-headers | wc -l)
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            pods_ready=true
        else
            print_status "Waiting for pods to be ready... ($ready_pods/$total_pods ready)"
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ "$pods_ready" = true ]; then
        print_success "All pods are running and ready!"
    else
        print_error "Not all pods became ready within the timeout period"
        kubectl get pods -l app=fastapi-app
        exit 1
    fi
    
    echo
}

# Function to get and display external IP
get_external_access() {
    print_header "CONFIGURING EXTERNAL ACCESS"
    
    print_status "Waiting for LoadBalancer to get external IP..."
    
    # Wait for external IP (max 10 minutes)
    local external_ip=""
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ] && [ -z "$external_ip" ]; do
        external_ip=$(kubectl get service fastapi-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -z "$external_ip" ] || [ "$external_ip" = "null" ]; then
            print_status "Waiting for external IP assignment... (attempt $((attempt+1))/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        print_success "External IP assigned: $external_ip"
        
        # Test connectivity
        print_status "Testing application connectivity..."
        sleep 30  # Give some time for the service to be fully ready
        
        if curl -f "http://$external_ip/health" &> /dev/null; then
            print_success "Application is accessible and healthy!"
        else
            print_warning "Application might not be fully ready yet. Please wait a few more minutes."
        fi
        
        # Display access information
        echo
        print_success "=== APPLICATION ACCESS INFORMATION ==="
        echo "Application URL: http://$external_ip"
        echo "Health Check:   http://$external_ip/health"
        echo "API Docs:       http://$external_ip/docs"
        echo "File Writer:    http://$external_ip/write-file (POST)"
        echo "List Files:     http://$external_ip/list-files"
        
    else
        print_error "Failed to get external IP within timeout period"
        print_status "You can check the service status with: kubectl get service fastapi-loadbalancer"
        exit 1
    fi
    
    echo
}

# Function to display verification commands
display_verification_commands() {
    print_header "DEPLOYMENT VERIFICATION COMMANDS"
    
    echo "Use these commands to verify your deployment:"
    echo
    echo "# Check deployment status"
    echo "kubectl get deployment fastapi-app"
    echo
    echo "# Check pod status"
    echo "kubectl get pods -l app=fastapi-app"
    echo
    echo "# Check service status"
    echo "kubectl get service fastapi-loadbalancer"
    echo
    echo "# Check persistent volume"
    echo "kubectl get pvc fastapi-pvc"
    echo
    echo "# View application logs"
    echo "kubectl logs -f deployment/fastapi-app"
    echo
    echo "# Test the application"
    echo "curl http://\$(kubectl get service fastapi-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/health"
    echo
    echo "# Run post-deployment verification script"
    echo "./verify-deployment.sh"
    
    echo
}

# Function to show help
show_help() {
    echo "AKS Deployment Script"
    echo
    echo "This script automates the complete deployment of the FastAPI application to Azure Kubernetes Service."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --skip-build    Skip Docker image build and push step"
    echo "  --skip-terraform Skip Terraform deployment (use existing infrastructure)"
    echo "  --help         Show this help message"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI (logged in)"
    echo "  - Docker (daemon running)"
    echo "  - Terraform"
    echo "  - kubectl"
    echo "  - jq"
    echo
    echo "The script will:"
    echo "  1. Check prerequisites"
    echo "  2. Build and push Docker image to ACR"
    echo "  3. Deploy infrastructure with Terraform"
    echo "  4. Configure kubectl access"
    echo "  5. Wait for deployment to be ready"
    echo "  6. Configure external access"
    echo "  7. Display verification commands"
}

# Main execution
main() {
    local skip_build=false
    local skip_terraform=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-terraform)
                skip_terraform=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_header "AZURE KUBERNETES SERVICE DEPLOYMENT"
    print_status "Starting deployment process..."
    print_status "Project directory: $PROJECT_DIR"
    print_status "Script directory: $SCRIPT_DIR"
    echo
    
    # Execute deployment steps
    check_prerequisites
    
    if [ "$skip_build" = false ]; then
        build_and_push_image
    else
        print_warning "Skipping Docker build step as requested"
        echo
    fi
    
    if [ "$skip_terraform" = false ]; then
        deploy_infrastructure
    else
        print_warning "Skipping Terraform deployment as requested"
        echo
    fi
    
    configure_kubectl
    wait_for_deployment
    get_external_access
    display_verification_commands
    
    print_header "DEPLOYMENT COMPLETED SUCCESSFULLY!"
    print_success "Your FastAPI application is now running on Azure Kubernetes Service!"
    print_status "Use the verification commands above to check the deployment status."
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
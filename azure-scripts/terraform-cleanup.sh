#!/bin/bash

# Terraform Cleanup Script for FastAPI Azure Web App
# This script destroys all resources created by Terraform

set -e  # Exit on any error

# Configuration
TERRAFORM_DIR="$(dirname "$0")"
PLAN_FILE="destroy.tfplan"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Azure CLI is installed and user is logged in
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi

    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run 'az login' first"
        exit 1
    fi
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" ]] && [[ ! -f ".terraform/terraform.tfstate" ]]; then
        log_warn "No Terraform state found. Nothing to destroy."
        exit 0
    fi
}

list_resources() {
    log_step "Listing resources to be destroyed..."
    cd "$TERRAFORM_DIR"
    
    terraform plan -destroy -out="$PLAN_FILE"
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create destroy plan"
        exit 1
    fi
}

confirm_destruction() {
    echo
    log_warn "This will DESTROY all Azure resources managed by this Terraform configuration!"
    log_warn "This action CANNOT BE UNDONE!"
    echo
    echo "Resources that will be destroyed:"
    echo "  - Resource Group and ALL contained resources"
    echo "  - Web App"
    echo "  - App Service Plan" 
    echo "  - Storage Account and ALL data"
    echo "  - All other resources in the configuration"
    echo
    read -p "Are you absolutely sure you want to continue? (type 'destroy' to confirm): " confirmation
    
    if [[ "$confirmation" != "destroy" ]]; then
        log_info "Destruction cancelled by user"
        rm -f "$PLAN_FILE"
        exit 0
    fi
}

terraform_destroy() {
    log_step "Destroying resources..."
    
    terraform apply "$PLAN_FILE"
    
    if [[ $? -ne 0 ]]; then
        log_error "Terraform destroy failed"
        exit 1
    fi
    
    log_info "All resources have been destroyed successfully"
}

cleanup_files() {
    log_step "Cleaning up temporary files..."
    
    # Remove plan file
    rm -f "$PLAN_FILE"
    
    # Optionally remove Terraform files (ask user)
    echo
    read -p "Remove Terraform state and cache files? (yes/no): " cleanup_terraform
    
    if [[ "$cleanup_terraform" == "yes" ]]; then
        rm -rf .terraform/
        rm -f terraform.tfstate*
        rm -f .terraform.lock.hcl
        log_info "Terraform files cleaned up"
    fi
}

# Main execution
main() {
    log_info "Starting Terraform cleanup..."
    
    check_prerequisites
    list_resources
    confirm_destruction
    terraform_destroy
    cleanup_files
    
    echo
    echo "==========================================="
    echo "         CLEANUP COMPLETE"
    echo "==========================================="
    log_info "All Azure resources have been destroyed!"
    echo "==========================================="
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Terraform Cleanup Script for FastAPI Azure Web App"
    echo
    echo "This script destroys all Azure resources created by Terraform."
    echo
    echo "Warning: This action cannot be undone!"
    echo
    echo "Prerequisites:"
    echo "  - Terraform installed"
    echo "  - Azure CLI installed and logged in"
    echo "  - Existing Terraform state file"
    echo
    echo "Usage: $0"
    echo "       $0 --help"
    exit 0
fi

# Run main function
main "$@"
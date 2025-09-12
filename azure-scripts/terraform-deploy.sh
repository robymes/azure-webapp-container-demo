#!/bin/bash

# Terraform Deployment Script for FastAPI Azure Web App
# This script initializes and applies Terraform configuration

set -e  # Exit on any error

# Configuration
TERRAFORM_DIR="$(dirname "$0")"
PLAN_FILE="terraform.tfplan"

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
        echo "Visit: https://www.terraform.io/downloads.html"
        exit 1
    fi
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | grep "Terraform" | cut -d' ' -f2 | sed 's/v//')
    log_info "Terraform version: $TERRAFORM_VERSION"
    
    # Check if Azure CLI is installed and user is logged in
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi

    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run 'az login' first"
        exit 1
    fi
    
    # Display current Azure subscription
    SUBSCRIPTION=$(az account show --query name -o tsv)
    log_info "Using Azure subscription: $SUBSCRIPTION"
    
    # Check if docker-compose.yml exists for reference
    if [[ ! -f "../docker-compose.yml" ]] && [[ ! -f "docker-compose.yml" ]]; then
        log_warn "docker-compose.yml not found. Make sure it exists in the project root."
    fi
}

terraform_init() {
    log_step "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    
    if [[ $? -ne 0 ]]; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    log_info "Terraform initialized successfully"
}

terraform_validate() {
    log_step "Validating Terraform configuration..."
    
    terraform validate
    
    if [[ $? -ne 0 ]]; then
        log_error "Terraform validation failed"
        exit 1
    fi
    
    log_info "Terraform configuration is valid"
}

terraform_plan() {
    log_step "Creating Terraform execution plan..."
    
    terraform plan -out="$PLAN_FILE"
    
    if [[ $? -ne 0 ]]; then
        log_error "Terraform planning failed"
        exit 1
    fi
    
    log_info "Terraform plan created successfully"
}

terraform_apply() {
    log_step "Applying Terraform configuration..."
    
    echo
    log_warn "This will create Azure resources that may incur costs."
    read -p "Do you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
    
    terraform apply "$PLAN_FILE"
    
    if [[ $? -ne 0 ]]; then
        log_error "Terraform apply failed"
        exit 1
    fi
    
    log_info "Terraform apply completed successfully"
}

show_outputs() {
    log_step "Displaying deployment information..."
    
    echo
    echo "=========================================="
    echo "         DEPLOYMENT COMPLETE"
    echo "=========================================="
    
    terraform output -json > outputs.json 2>/dev/null || true
    
    if [[ -f "outputs.json" ]]; then
        WEB_APP_URL=$(cat outputs.json | jq -r '.web_app_url.value // empty')
        WEB_APP_NAME=$(cat outputs.json | jq -r '.web_app_name.value // empty')
        RESOURCE_GROUP=$(cat outputs.json | jq -r '.resource_group_name.value // empty')
        STORAGE_ACCOUNT=$(cat outputs.json | jq -r '.storage_account_name.value // empty')
        
        if [[ -n "$WEB_APP_URL" ]]; then
            echo "Web App URL: $WEB_APP_URL"
            echo "Web App Name: $WEB_APP_NAME"
            echo "Resource Group: $RESOURCE_GROUP"
            echo "Storage Account: $STORAGE_ACCOUNT"
            echo
            echo "API Endpoints:"
            echo "  Health Check: $WEB_APP_URL/health"
            echo "  Write File: $WEB_APP_URL/write-file"
            echo "  List Files: $WEB_APP_URL/list-files"
            echo
            echo "To test the API:"
            echo "curl -X POST \"$WEB_APP_URL/write-file\" \\"
            echo "  -H \"Content-Type: application/json\" \\"
            echo "  -d '{\"content\":\"Hello World!\",\"filename\":\"test.txt\"}'"
        fi
        
        rm -f outputs.json
    else
        terraform output
    fi
    
    echo "=========================================="
}

configure_docker_compose() {
    log_step "Configuring Docker Compose deployment..."
    log_warn "Docker Compose configuration needs to be set manually via Azure CLI or Portal"
    
    if [[ -f "outputs.json" ]]; then
        WEB_APP_NAME=$(cat outputs.json | jq -r '.web_app_name.value // empty')
        RESOURCE_GROUP=$(cat outputs.json | jq -r '.resource_group_name.value // empty')
        
        if [[ -n "$WEB_APP_NAME" ]] && [[ -n "$RESOURCE_GROUP" ]]; then
            echo
            log_info "To configure Docker Compose, run:"
            echo "cd .."
            echo "az webapp config container set \\"
            echo "  --name \"$WEB_APP_NAME\" \\"
            echo "  --resource-group \"$RESOURCE_GROUP\" \\"
            echo "  --multicontainer-config-type compose \\"
            echo "  --multicontainer-config-file docker-compose.yml"
        fi
    fi
}

cleanup_plan() {
    # Clean up plan file
    if [[ -f "$PLAN_FILE" ]]; then
        rm -f "$PLAN_FILE"
    fi
}

# Main execution
main() {
    trap cleanup_plan EXIT
    
    log_info "Starting Terraform deployment..."
    
    check_prerequisites
    terraform_init
    terraform_validate
    terraform_plan
    terraform_apply
    show_outputs
    configure_docker_compose
    
    log_info "Deployment script completed!"
    echo
    log_warn "Note: You may need to configure Docker Compose manually and restart the web app."
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Terraform Deployment Script for FastAPI Azure Web App"
    echo
    echo "This script deploys Azure infrastructure using Terraform including:"
    echo "  - Resource Group"
    echo "  - Storage Account with File Share"
    echo "  - App Service Plan (Linux, B1 SKU)"
    echo "  - Web App for Containers"
    echo "  - Storage mount configuration"
    echo
    echo "Prerequisites:"
    echo "  - Terraform installed (>= 1.0)"
    echo "  - Azure CLI installed and logged in (az login)"
    echo "  - Proper Azure subscription permissions"
    echo
    echo "Usage: $0"
    echo "       $0 --help"
    exit 0
fi

# Run main function
main "$@"
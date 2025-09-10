#!/bin/bash

# Cleanup script to remove all Azure resources created for the FastAPI application

set -e

# Configuration
RESOURCE_GROUP="rg-fastapi-webapp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

confirm_deletion() {
    echo "This will delete the entire resource group: $RESOURCE_GROUP"
    echo "All resources including:"
    echo "  - Web App"
    echo "  - App Service Plan"
    echo "  - Storage Account and all data"
    echo "  - All other resources in the group"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
}

list_resources() {
    log_info "Resources to be deleted:"
    az resource list --resource-group "$RESOURCE_GROUP" --output table 2>/dev/null || {
        log_warn "Resource group not found or no resources to display"
        return 0
    }
}

delete_resource_group() {
    log_info "Deleting resource group: $RESOURCE_GROUP"
    az group delete \
        --name "$RESOURCE_GROUP" \
        --yes \
        --no-wait
    
    log_info "Deletion initiated. It may take several minutes to complete."
    log_info "You can check the status with: az group show --name $RESOURCE_GROUP"
}

# Main execution
main() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi

    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run 'az login' first"
        exit 1
    fi

    list_resources
    echo
    confirm_deletion
    delete_resource_group
    
    log_info "Cleanup completed!"
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Azure Resources Cleanup Script"
    echo
    echo "This script deletes the entire resource group and all contained resources."
    echo
    echo "Warning: This action cannot be undone!"
    echo
    echo "Usage: $0"
    echo "       $0 --help"
    exit 0
fi

# Run main function
main "$@"
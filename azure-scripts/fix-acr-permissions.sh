#!/bin/bash

# Fix ACR permissions for Container App managed identity
# Use this script if you're getting "unable to pull image using Managed identity" errors

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    print_status "=== Fixing ACR Permissions for Container App ==="
    echo
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        print_error "No terraform.tfstate found. Please deploy infrastructure first."
        exit 1
    fi
    
    # Get details from Terraform outputs
    print_status "Getting resource details from Terraform..."
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    CONTAINER_APP_NAME=$(terraform output -raw container_app_name 2>/dev/null || echo "")
    ACR_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "")
    
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$CONTAINER_APP_NAME" ] || [ -z "$ACR_NAME" ]; then
        print_error "Could not get resource details from Terraform outputs"
        exit 1
    fi
    
    print_status "Resource Group: $RESOURCE_GROUP"
    print_status "Container App: $CONTAINER_APP_NAME"
    print_status "ACR Name: $ACR_NAME"
    echo
    
    # Get Container App managed identity
    print_status "Getting Container App managed identity..."
    PRINCIPAL_ID=$(az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "identity.principalId" -o tsv)
    
    if [ -z "$PRINCIPAL_ID" ] || [ "$PRINCIPAL_ID" = "null" ]; then
        print_error "Container App does not have a managed identity or it's not enabled"
        print_status "Enabling managed identity for Container App..."
        
        # Enable system-assigned managed identity
        PRINCIPAL_ID=$(az containerapp identity assign --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" --system-assigned --query "principalId" -o tsv)
        
        if [ -z "$PRINCIPAL_ID" ] || [ "$PRINCIPAL_ID" = "null" ]; then
            print_error "Failed to enable managed identity"
            exit 1
        fi
        
        print_success "Managed identity enabled. Principal ID: $PRINCIPAL_ID"
    else
        print_status "Container App Principal ID: $PRINCIPAL_ID"
    fi
    
    # Get ACR resource ID
    ACR_RESOURCE_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"
    print_status "ACR Resource ID: $ACR_RESOURCE_ID"
    
    # Check existing role assignments
    print_status "Checking existing role assignments..."
    EXISTING_ASSIGNMENTS=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$ACR_RESOURCE_ID" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table)
    
    if [ -n "$EXISTING_ASSIGNMENTS" ]; then
        print_status "Existing role assignments:"
        echo "$EXISTING_ASSIGNMENTS"
    else
        print_warning "No existing role assignments found"
    fi
    
    # Check if AcrPull role exists
    ACRPULL_ASSIGNMENT=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$ACR_RESOURCE_ID" --role "AcrPull" --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$ACRPULL_ASSIGNMENT" ] || [ "$ACRPULL_ASSIGNMENT" = "null" ]; then
        print_warning "AcrPull role assignment is missing. Creating it now..."
        
        if az role assignment create \
            --assignee "$PRINCIPAL_ID" \
            --role "AcrPull" \
            --scope "$ACR_RESOURCE_ID"; then
            print_success "AcrPull role assignment created successfully!"
        else
            print_error "Failed to create AcrPull role assignment"
            exit 1
        fi
    else
        print_success "AcrPull role assignment already exists"
    fi
    
    # Wait for role assignment to propagate
    print_status "Waiting 30 seconds for role assignment to propagate..."
    sleep 30
    
    # Verify the assignment
    print_status "Verifying role assignment..."
    FINAL_CHECK=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$ACR_RESOURCE_ID" --role "AcrPull" --query "[0].roleDefinitionName" -o tsv)
    
    if [ "$FINAL_CHECK" = "AcrPull" ]; then
        print_success "✓ AcrPull role assignment verified!"
        echo
        print_success "=== ACR Permissions Fixed! ==="
        print_status "You can now update your container app:"
        print_status "  ./update-container.sh"
    else
        print_error "Role assignment verification failed"
        exit 1
    fi
}

# Run main function
main
#!/bin/bash

# Container-only update script for Azure Container Apps
# Use this when you only need to update the Docker image without touching infrastructure

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
DOCKER_TAG=${1:-"latest"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Help function
show_help() {
    echo "Container Update Script for Azure Container Apps"
    echo
    echo "Usage: $0 [DOCKER_TAG]"
    echo
    echo "Arguments:"
    echo "  DOCKER_TAG    Tag for the Docker image (default: latest)"
    echo
    echo "This script will:"
    echo "  1. Build and push Docker image to Azure Container Registry"
    echo "  2. Update the Container App to use the new image"
    echo "  3. Verify the deployment"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in"
    echo "  - Docker installed and running"
    echo "  - Infrastructure already deployed via Terraform"
}

# Check for help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

main() {
    print_status "=== Container App Update ===" 
    print_status "Docker tag: $DOCKER_TAG"
    echo
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Check if infrastructure exists
    if [ ! -f "terraform.tfstate" ]; then
        print_error "No terraform.tfstate found. Please deploy infrastructure first using:"
        print_error "  ./full-deploy.sh or ./deploy-with-retry.sh"
        exit 1
    fi
    
    # Step 1: Build and push Docker image
    print_status "Step 1: Building and pushing Docker image..."
    if [ -f "./docker-build-push.sh" ]; then
        ./docker-build-push.sh "$DOCKER_TAG"
    else
        print_error "docker-build-push.sh not found!"
        exit 1
    fi
    print_success "Docker image build and push completed!"
    echo
    
    # Step 2: Get container app details from Terraform outputs
    print_status "Step 2: Getting Container App details..."
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    CONTAINER_APP_NAME=$(terraform output -raw container_app_name 2>/dev/null || echo "")
    ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server 2>/dev/null || echo "")
    ACR_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "")
    
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$CONTAINER_APP_NAME" ] || [ -z "$ACR_LOGIN_SERVER" ]; then
        print_error "Could not get Container App details from Terraform outputs"
        print_error "Please ensure infrastructure is deployed and Terraform state is valid"
        exit 1
    fi
    
    print_status "Container App: $CONTAINER_APP_NAME"
    print_status "Resource Group: $RESOURCE_GROUP"
    print_status "Registry: $ACR_LOGIN_SERVER"
    echo
    
    # Step 2.5: Verify and fix ACR permissions
    print_status "Step 2.5: Verifying ACR permissions..."
    
    # Get the Container App's managed identity principal ID
    PRINCIPAL_ID=$(az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "identity.principalId" -o tsv)
    
    if [ -n "$PRINCIPAL_ID" ] && [ "$PRINCIPAL_ID" != "null" ]; then
        print_status "Container App Principal ID: $PRINCIPAL_ID"
        
        # Check if AcrPull role assignment exists
        EXISTING_ASSIGNMENT=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME" --role "AcrPull" --query "[0].id" -o tsv 2>/dev/null || echo "")
        
        if [ -z "$EXISTING_ASSIGNMENT" ] || [ "$EXISTING_ASSIGNMENT" = "null" ]; then
            print_warning "AcrPull role assignment missing. Creating it now..."
            
            if az role assignment create \
                --assignee "$PRINCIPAL_ID" \
                --role "AcrPull" \
                --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"; then
                print_success "AcrPull role assignment created!"
                print_status "Waiting 30 seconds for role assignment to propagate..."
                sleep 30
            else
                print_error "Failed to create AcrPull role assignment"
                exit 1
            fi
        else
            print_success "AcrPull role assignment already exists"
        fi
    else
        print_error "Could not get Container App's managed identity principal ID"
        exit 1
    fi
    
    # Step 3: Update Container App with new image
    print_status "Step 3: Updating Container App with new image..."
    
    NEW_IMAGE="$ACR_LOGIN_SERVER/fastapi-app:$DOCKER_TAG"
    print_status "New image: $NEW_IMAGE"
    
    if az containerapp update \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$NEW_IMAGE"; then
        print_success "Container App updated successfully!"
    else
        print_error "Failed to update Container App"
        exit 1
    fi
    
    # Step 4: Wait and verify deployment
    print_status "Step 4: Verifying deployment..."
    sleep 15
    
    CONTAINER_APP_URL=$(terraform output -raw container_app_url 2>/dev/null || echo "")
    if [ -n "$CONTAINER_APP_URL" ]; then
        print_success "=== Update Complete! ==="
        print_status "Container App URL: $CONTAINER_APP_URL"
        print_status "Health Check: $CONTAINER_APP_URL/health"
        echo
        
        print_status "Testing health endpoint..."
        sleep 10
        
        if curl -f "$CONTAINER_APP_URL/health" --max-time 30 2>/dev/null; then
            echo
            print_success "Health check passed! Your updated application is running."
            print_status "Image: $NEW_IMAGE"
        else
            echo
            print_warning "Health check failed. The app might still be starting up."
            print_status "Please wait a few minutes and try accessing: $CONTAINER_APP_URL"
        fi
    else
        print_warning "Could not get Container App URL from Terraform outputs"
        print_status "Please check the Container App status manually in the Azure portal"
    fi
}

# Run main function
main
#!/bin/bash

# Enhanced deployment script with Container Apps polling error handling
# This script handles the "unimplemented polling status Unknown" error

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
MAX_RETRIES=3
RETRY_DELAY=60

# Help function
show_help() {
    echo "Enhanced Azure Container Apps Deployment Script"
    echo
    echo "Usage: $0 [DOCKER_TAG]"
    echo
    echo "Arguments:"
    echo "  DOCKER_TAG    Tag for the Docker image (default: latest)"
    echo
    echo "This script will:"
    echo "  1. Deploy/update Azure infrastructure with Terraform (with retry logic)"
    echo "  2. Build and push Docker image to Azure Container Registry"
    echo "  3. Update the Container App to use the new image"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in"
    echo "  - Terraform installed"
    echo "  - Docker installed and running"
}

# Check for help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

main() {
    print_status "=== Enhanced Azure Container Apps Deployment ==="
    print_status "Docker tag: $DOCKER_TAG"
    echo
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Step 1: Initialize Terraform
    print_status "Step 1: Initializing Terraform..."
    terraform init -upgrade
    print_success "Terraform initialized!"
    
    # Step 2: Plan
    print_status "Step 2: Creating Terraform plan..."
    terraform plan -out=tfplan
    print_success "Terraform plan created!"
    
    # Step 3: Apply with retry logic
    print_status "Step 3: Applying Terraform configuration with retry logic..."
    
    RETRY_COUNT=0
    SUCCESS=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$SUCCESS" = false ]; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        print_status "Attempt $RETRY_COUNT of $MAX_RETRIES..."
        
        if terraform apply tfplan; then
            SUCCESS=true
            print_success "Terraform apply succeeded!"
        else
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                print_warning "Terraform apply failed. This might be due to Container Apps polling issues."
                print_status "Waiting $RETRY_DELAY seconds before retry..."
                sleep $RETRY_DELAY
                
                # Check if resources were actually created despite the error
                print_status "Checking if resources were created despite the error..."
                
                # Refresh state to get latest status
                terraform refresh
                
                # Check if Container App exists
                CONTAINER_APP_NAME=$(terraform output -raw container_app_name 2>/dev/null || echo "")
                RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
                
                if [ -n "$CONTAINER_APP_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
                    print_status "Checking if Container App actually exists in Azure..."
                    if az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
                        print_success "Container App was actually created successfully despite the error!"
                        SUCCESS=true
                        break
                    fi
                fi
                
                print_status "Container App not found. Recreating plan for retry..."
                terraform plan -out=tfplan
            else
                print_error "Terraform apply failed after $MAX_RETRIES attempts."
                
                # Final check if resources exist despite error
                print_status "Performing final check for existing resources..."
                terraform refresh
                
                CONTAINER_APP_NAME=$(terraform output -raw container_app_name 2>/dev/null || echo "")
                RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
                
                if [ -n "$CONTAINER_APP_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
                    if az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
                        print_warning "Resources were actually created despite Terraform errors!"
                        print_status "Importing existing resources into Terraform state..."
                        
                        # Try to import the container app
                        CONTAINER_APP_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/$CONTAINER_APP_NAME"
                        terraform import azurerm_container_app.main "$CONTAINER_APP_ID" || true
                        
                        SUCCESS=true
                    fi
                fi
                
                if [ "$SUCCESS" = false ]; then
                    exit 1
                fi
            fi
        fi
    done
    
    if [ "$SUCCESS" = true ]; then
        print_success "Infrastructure deployment completed!"
        echo
        
        # Wait a moment for resources to be fully ready
        print_status "Waiting 30 seconds for resources to be fully ready..."
        sleep 30
        
        # Step 4: Build and push Docker image
        print_status "Step 4: Building and pushing Docker image..."
        if [ -f "./docker-build-push.sh" ]; then
            ./docker-build-push.sh "$DOCKER_TAG"
        else
            print_error "docker-build-push.sh not found!"
            exit 1
        fi
        print_success "Docker image build and push completed!"
        echo
        
        # Step 5: Update Container App with new image
        print_status "Step 5: Updating Container App with new image..."
        
        # Get container app details from Terraform outputs
        RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
        CONTAINER_APP_NAME=$(terraform output -raw container_app_name 2>/dev/null || echo "")
        ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server 2>/dev/null || echo "")
        
        if [ -n "$RESOURCE_GROUP" ] && [ -n "$CONTAINER_APP_NAME" ] && [ -n "$ACR_LOGIN_SERVER" ]; then
            print_status "Updating Container App: $CONTAINER_APP_NAME in resource group: $RESOURCE_GROUP"
            
            # Update container app with new image
            if az containerapp update \
                --name "$CONTAINER_APP_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --image "$ACR_LOGIN_SERVER/fastapi-app:$DOCKER_TAG"; then
                print_success "Container App updated successfully!"
            else
                print_warning "Failed to update Container App, but deployment may still work"
            fi
            
            # Wait a bit and show the URL
            sleep 15
            CONTAINER_APP_URL=$(terraform output -raw container_app_url 2>/dev/null || echo "")
            if [ -n "$CONTAINER_APP_URL" ]; then
                print_success "=== Deployment Complete! ==="
                print_status "Container App URL: $CONTAINER_APP_URL"
                print_status "Health Check: $CONTAINER_APP_URL/health"
                echo
                print_status "Testing health endpoint..."
                sleep 10
                if curl -f "$CONTAINER_APP_URL/health" --max-time 30 2>/dev/null; then
                    echo
                    print_success "Health check passed! Your application is running."
                else
                    echo
                    print_warning "Health check failed. The app might still be starting up."
                    print_status "Please wait a few minutes and try accessing: $CONTAINER_APP_URL"
                fi
            fi
        else
            print_warning "Could not get Container App details from Terraform outputs"
            print_status "Please check the Container App status manually in the Azure portal"
        fi
    else
        print_error "Deployment failed after all retry attempts."
        exit 1
    fi
    
    # Cleanup plan file
    rm -f tfplan
}

# Run main function
main
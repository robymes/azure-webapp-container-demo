#!/bin/bash

# Complete deployment script for Azure webapp with container registry
# This script will:
# 1. Deploy infrastructure with Terraform
# 2. Build and push Docker image to ACR
# 3. Restart the web app to use the new image

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
    echo "Complete Azure Deployment Script"
    echo
    echo "Usage: $0 [DOCKER_TAG]"
    echo
    echo "Arguments:"
    echo "  DOCKER_TAG    Tag for the Docker image (default: latest)"
    echo
    echo "This script will:"
    echo "  1. Deploy/update Azure infrastructure with Terraform"
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
    print_status "=== Complete Azure Deployment ==="
    print_status "Docker tag: $DOCKER_TAG"
    echo
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Step 1: Deploy infrastructure
    print_status "Step 1: Deploying Azure infrastructure with Terraform..."
    if [ -f "./terraform-deploy.sh" ]; then
        ./terraform-deploy.sh
    else
        print_status "Running Terraform manually..."
        terraform init
        terraform plan
        terraform apply -auto-approve
    fi
    print_success "Infrastructure deployment completed!"
    echo
    
    # Wait a moment for resources to be fully ready
    print_status "Waiting 30 seconds for resources to be fully ready..."
    sleep 30
    
    # Step 2: Build and push Docker image
    print_status "Step 2: Building and pushing Docker image..."
    ./docker-build-push.sh "$DOCKER_TAG"
    print_success "Docker image build and push completed!"
    echo
    
    # Step 3: Update Container App with new image
    print_status "Step 3: Updating Container App with new image..."
    
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
}

# Run main function
main
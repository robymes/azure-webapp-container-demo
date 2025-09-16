#!/bin/bash

# Script to build and push Docker image to Azure Container Registry
# Usage: ./docker-build-push.sh [tag] [dockerfile_path]

set -e  # Exit on any error

# Configuration
IMAGE_NAME="fastapi-app"
DEFAULT_TAG="latest"
DEFAULT_DOCKERFILE_PATH="../"

# Parse arguments
TAG=${1:-$DEFAULT_TAG}
DOCKERFILE_PATH=${2:-$DEFAULT_DOCKERFILE_PATH}

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

# Function to check if Azure CLI is installed and user is logged in
check_azure_cli() {
    print_status "Checking Azure CLI installation..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    print_status "Checking Azure CLI login status..."
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Azure CLI is installed and you are logged in."
}

# Function to get ACR details from Terraform outputs
get_acr_details() {
    print_status "Reading Terraform outputs..."
    
    if [ ! -f "terraform.tfstate" ]; then
        print_error "terraform.tfstate not found. Please run 'terraform apply' first."
        exit 1
    fi
    
    # Try to get outputs from terraform output command first
    if command -v terraform &> /dev/null; then
        ACR_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "")
        ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server 2>/dev/null || echo "")
    fi
    
    # If terraform command failed, try to parse the state file
    if [ -z "$ACR_NAME" ] || [ -z "$ACR_LOGIN_SERVER" ]; then
        print_warning "Could not get outputs from terraform command, parsing state file..."
        
        # Parse JSON state file for ACR details
        ACR_NAME=$(cat terraform.tfstate | jq -r '.outputs.container_registry_name.value // empty' 2>/dev/null || echo "")
        ACR_LOGIN_SERVER=$(cat terraform.tfstate | jq -r '.outputs.container_registry_login_server.value // empty' 2>/dev/null || echo "")
        
        if [ -z "$ACR_NAME" ] || [ -z "$ACR_LOGIN_SERVER" ]; then
            print_error "Could not retrieve ACR details from Terraform state."
            print_error "Make sure Terraform has been applied and the ACR is created."
            exit 1
        fi
    fi
    
    print_success "ACR Details retrieved:"
    print_status "  Registry Name: $ACR_NAME"
    print_status "  Login Server: $ACR_LOGIN_SERVER"
}

# Function to login to ACR
login_to_acr() {
    print_status "Logging in to Azure Container Registry..."
    
    if az acr login --name "$ACR_NAME"; then
        print_success "Successfully logged in to ACR: $ACR_NAME"
    else
        print_error "Failed to login to ACR. Please check your permissions."
        exit 1
    fi
}

# Function to build Docker image
build_image() {
    print_status "Building Docker image..."
    print_status "  Image: $IMAGE_NAME:$TAG"
    print_status "  Dockerfile path: $DOCKERFILE_PATH"
    print_status "  Target registry: $ACR_LOGIN_SERVER"
    
    FULL_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG"
    
    if docker build -t "$FULL_IMAGE_NAME" "$DOCKERFILE_PATH"; then
        print_success "Docker image built successfully: $FULL_IMAGE_NAME"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Function to push image to ACR
push_image() {
    print_status "Pushing image to Azure Container Registry..."
    
    FULL_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG"
    
    if docker push "$FULL_IMAGE_NAME"; then
        print_success "Image pushed successfully to ACR!"
        print_success "Full image name: $FULL_IMAGE_NAME"
    else
        print_error "Failed to push image to ACR"
        exit 1
    fi
}

# Function to verify image in ACR
verify_image() {
    print_status "Verifying image in ACR..."
    
    if az acr repository show --name "$ACR_NAME" --repository "$IMAGE_NAME" > /dev/null 2>&1; then
        print_success "Image verified in ACR repository!"
        
        # Show available tags
        print_status "Available tags for $IMAGE_NAME:"
        az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output table
    else
        print_warning "Could not verify image in ACR (this might be normal for first-time push)"
    fi
}

# Main execution
main() {
    print_status "=== Azure Container Registry Docker Build & Push Script ==="
    print_status "Image: $IMAGE_NAME:$TAG"
    print_status "Dockerfile path: $DOCKERFILE_PATH"
    echo
    
    # Check prerequisites
    check_azure_cli
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Get ACR details from Terraform
    get_acr_details
    
    # Login to ACR
    login_to_acr
    
    # Build image
    build_image
    
    # Push image
    push_image
    
    # Verify image
    verify_image
    
    echo
    print_success "=== Build and Push Complete! ==="
    print_status "Your image is now available at: $ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG"
    print_status "The AKS deployment will use this image for the FastAPI application."
}

# Help function
show_help() {
    echo "Azure Container Registry Docker Build & Push Script"
    echo
    echo "Usage: $0 [TAG] [DOCKERFILE_PATH]"
    echo
    echo "Arguments:"
    echo "  TAG              Docker image tag (default: latest)"
    echo "  DOCKERFILE_PATH  Path to Dockerfile directory (default: ../)"
    echo
    echo "Examples:"
    echo "  $0                    # Build with tag 'latest' from parent directory"
    echo "  $0 v1.0.0            # Build with tag 'v1.0.0'"
    echo "  $0 latest /path/to/docker/context"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in (az login)"
    echo "  - Docker installed and running"
    echo "  - Terraform applied (ACR must exist)"
    echo "  - Proper permissions to push to the ACR"
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Run main function
main
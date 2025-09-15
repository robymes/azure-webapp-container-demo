#!/bin/bash

# Cleanup script for Azure Container Apps demo environment
# This script will completely remove all Azure resources created by Terraform

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

# Help function
show_help() {
    echo "Azure Resources Cleanup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -f, --force     Skip confirmation prompts"
    echo "  -h, --help      Show this help message"
    echo
    echo "This script will:"
    echo "  1. Destroy all Terraform-managed resources"
    echo "  2. Clean up Terraform state files"
    echo "  3. Optionally remove the entire resource group"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in"
    echo "  - Terraform installed"
}

# Parse command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
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

main() {
    print_status "=== Azure Resources Cleanup ==="
    echo
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "No terraform.tfstate file found. Resources may have already been cleaned up."
        
        if [ "$FORCE" = false ]; then
            echo
            read -p "Do you want to continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Cleanup cancelled."
                exit 0
            fi
        fi
    fi
    
    # Show what will be destroyed
    if [ -f "terraform.tfstate" ]; then
        print_status "The following resources will be destroyed:"
        echo
        terraform show -no-color | grep -E "^resource \"" | sed 's/resource "/  - /' | sed 's/" {//'
        echo
    fi
    
    # Confirmation prompt
    if [ "$FORCE" = false ]; then
        print_warning "This will PERMANENTLY DELETE all Azure resources created by this Terraform configuration!"
        echo
        read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
        echo
        if [ "$REPLY" != "yes" ]; then
            print_status "Cleanup cancelled."
            exit 0
        fi
    fi
    
    # Step 1: Initialize Terraform (in case of version changes)
    print_status "Step 1: Initializing Terraform..."
    if terraform init; then
        print_success "Terraform initialized!"
    else
        print_error "Failed to initialize Terraform"
        exit 1
    fi
    
    # Step 2: Destroy all resources
    print_status "Step 2: Destroying all Azure resources..."
    if terraform destroy -auto-approve; then
        print_success "All Azure resources have been destroyed!"
    else
        print_error "Failed to destroy some resources. Check the output above for details."
        print_warning "You may need to:"
        print_warning "1. Run 'terraform destroy' again"
        print_warning "2. Manually delete remaining resources in the Azure portal"
        print_warning "3. Check for any resource dependencies or locks"
        exit 1
    fi
    
    # Step 3: Clean up Terraform files
    print_status "Step 3: Cleaning up Terraform state files..."
    
    # Remove state files
    if [ -f "terraform.tfstate" ]; then
        rm terraform.tfstate
        print_status "Removed terraform.tfstate"
    fi
    
    if [ -f "terraform.tfstate.backup" ]; then
        rm terraform.tfstate.backup
        print_status "Removed terraform.tfstate.backup"
    fi
    
    # Remove .terraform directory
    if [ -d ".terraform" ]; then
        rm -rf .terraform
        print_status "Removed .terraform directory"
    fi
    
    # Remove lock file
    if [ -f ".terraform.lock.hcl" ]; then
        rm .terraform.lock.hcl
        print_status "Removed .terraform.lock.hcl"
    fi
    
    print_success "Terraform state files cleaned up!"
    
    echo
    print_success "=== Cleanup Complete! ==="
    print_status "All Azure resources and Terraform state have been removed."
    print_status "The demo environment has been completely cleaned up."
    print_status ""
    print_status "Next steps:"
    print_status "- You can now run './full-deploy.sh' to create a fresh environment"
    print_status "- All resource names will be regenerated with new random suffixes"
}

# Run main function
main
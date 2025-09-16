#!/bin/bash
# External Storage Access Script
# Provides multiple methods to access Azure Files with Managed Identity authentication
# No shared keys required - uses Azure AD authentication

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to get resource names from Terraform outputs
get_terraform_outputs() {
    if [ ! -f "terraform.tfstate" ]; then
        print_error "terraform.tfstate not found. Please run terraform apply first."
        exit 1
    fi
    
    export RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    export STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null || echo "")
    export FILE_SHARE=$(terraform output -raw file_share_name 2>/dev/null || echo "")
    
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$STORAGE_ACCOUNT" ] || [ -z "$FILE_SHARE" ]; then
        print_error "Could not retrieve all required Terraform outputs"
        print_error "RESOURCE_GROUP: $RESOURCE_GROUP"
        print_error "STORAGE_ACCOUNT: $STORAGE_ACCOUNT"
        print_error "FILE_SHARE: $FILE_SHARE"
        exit 1
    fi
    
    print_status "Retrieved Terraform outputs:"
    print_status "  Resource Group: $RESOURCE_GROUP"
    print_status "  Storage Account: $STORAGE_ACCOUNT"
    print_status "  File Share: $FILE_SHARE"
}

# Function to check Azure CLI login
check_azure_login() {
    print_header "Checking Azure CLI authentication..."
    
    if ! az account show >/dev/null 2>&1; then
        print_warning "Not logged in to Azure CLI. Please log in:"
        az login
    fi
    
    local account_info=$(az account show --query '{name:name, tenantId:tenantId, subscriptionId:id}' -o table 2>/dev/null)
    print_status "Current Azure account:"
    echo "$account_info"
}

# Function to list files in Azure Files
list_files() {
    print_header "Listing files in Azure Files share..."
    
    print_status "Using Azure AD authentication (no shared keys)"
    
    az storage file list \
        --account-name "$STORAGE_ACCOUNT" \
        --share-name "$FILE_SHARE" \
        --auth-mode login \
        --output table
    
    print_status "Files listed successfully using Managed Identity authentication"
}

# Function to upload a file
upload_file() {
    local source_file="$1"
    local dest_path="$2"
    
    if [ -z "$source_file" ]; then
        print_error "Source file not specified"
        echo "Usage: $0 upload <source_file> [destination_path]"
        exit 1
    fi
    
    if [ ! -f "$source_file" ]; then
        print_error "Source file '$source_file' does not exist"
        exit 1
    fi
    
    if [ -z "$dest_path" ]; then
        dest_path=$(basename "$source_file")
    fi
    
    print_header "Uploading file '$source_file' to '$dest_path'..."
    
    az storage file upload \
        --account-name "$STORAGE_ACCOUNT" \
        --share-name "$FILE_SHARE" \
        --source "$source_file" \
        --path "$dest_path" \
        --auth-mode login
    
    print_status "File uploaded successfully: $dest_path"
}

# Function to download a file
download_file() {
    local remote_path="$1"
    local local_path="$2"
    
    if [ -z "$remote_path" ]; then
        print_error "Remote file path not specified"
        echo "Usage: $0 download <remote_path> [local_path]"
        exit 1
    fi
    
    if [ -z "$local_path" ]; then
        local_path=$(basename "$remote_path")
    fi
    
    print_header "Downloading file '$remote_path' to '$local_path'..."
    
    az storage file download \
        --account-name "$STORAGE_ACCOUNT" \
        --share-name "$FILE_SHARE" \
        --path "$remote_path" \
        --dest "$local_path" \
        --auth-mode login
    
    print_status "File downloaded successfully: $local_path"
}

# Function to create a directory
create_directory() {
    local dir_path="$1"
    
    if [ -z "$dir_path" ]; then
        print_error "Directory path not specified"
        echo "Usage: $0 mkdir <directory_path>"
        exit 1
    fi
    
    print_header "Creating directory '$dir_path'..."
    
    az storage directory create \
        --account-name "$STORAGE_ACCOUNT" \
        --share-name "$FILE_SHARE" \
        --name "$dir_path" \
        --auth-mode login
    
    print_status "Directory created successfully: $dir_path"
}

# Function to delete a file
delete_file() {
    local file_path="$1"
    
    if [ -z "$file_path" ]; then
        print_error "File path not specified"
        echo "Usage: $0 delete <file_path>"
        exit 1
    fi
    
    print_warning "This will permanently delete the file '$file_path'"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_header "Deleting file '$file_path'..."
        
        az storage file delete \
            --account-name "$STORAGE_ACCOUNT" \
            --share-name "$FILE_SHARE" \
            --path "$file_path" \
            --auth-mode login
        
        print_status "File deleted successfully: $file_path"
    else
        print_status "Operation cancelled"
    fi
}

# Function to show file properties
show_file_info() {
    local file_path="$1"
    
    if [ -z "$file_path" ]; then
        print_error "File path not specified"
        echo "Usage: $0 info <file_path>"
        exit 1
    fi
    
    print_header "Getting file information for '$file_path'..."
    
    az storage file show \
        --account-name "$STORAGE_ACCOUNT" \
        --share-name "$FILE_SHARE" \
        --path "$file_path" \
        --auth-mode login \
        --output table
}

# Function to test connectivity
test_connectivity() {
    print_header "Testing connectivity to Azure Files..."
    
    # Test storage account accessibility
    print_status "Testing storage account access..."
    az storage account show \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --query '{name:name, location:location, sku:sku.name, accessTier:accessTier}' \
        --output table
    
    # Test file share accessibility
    print_status "Testing file share access..."
    az storage share show \
        --account-name "$STORAGE_ACCOUNT" \
        --name "$FILE_SHARE" \
        --auth-mode login \
        --query '{name:name, quota:quota, accessTier:accessTier, metadata:metadata}' \
        --output table
    
    print_status "Connectivity test completed successfully!"
}

# Function to show usage
show_usage() {
    echo "Azure Files External Access Script"
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  list                    - List all files in the share"
    echo "  upload <file> [dest]    - Upload a local file"
    echo "  download <remote> [local] - Download a remote file"
    echo "  mkdir <path>            - Create a directory"
    echo "  delete <file>           - Delete a file"
    echo "  info <file>             - Show file information"
    echo "  test                    - Test connectivity"
    echo "  help                    - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 upload ./data.txt remote-data.txt"
    echo "  $0 download remote-file.txt ./local-file.txt"
    echo "  $0 mkdir uploads"
    echo "  $0 info remote-file.txt"
    echo ""
    echo "Note: This script uses Azure AD authentication - no shared keys required!"
}

# Main script logic
main() {
    local command="$1"
    
    case "$command" in
        "list")
            get_terraform_outputs
            check_azure_login
            list_files
            ;;
        "upload")
            get_terraform_outputs
            check_azure_login
            upload_file "$2" "$3"
            ;;
        "download")
            get_terraform_outputs
            check_azure_login
            download_file "$2" "$3"
            ;;
        "mkdir")
            get_terraform_outputs
            check_azure_login
            create_directory "$2"
            ;;
        "delete")
            get_terraform_outputs
            check_azure_login
            delete_file "$2"
            ;;
        "info")
            get_terraform_outputs
            check_azure_login
            show_file_info "$2"
            ;;
        "test")
            get_terraform_outputs
            check_azure_login
            test_connectivity
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
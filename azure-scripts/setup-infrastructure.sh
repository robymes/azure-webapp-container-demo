#!/bin/bash

# Azure Web App with Docker Compose and Persistent Storage Setup Script
# This script creates all necessary Azure resources for the FastAPI application

set -e  # Exit on any error

# Configuration variables - Update these as needed
RESOURCE_GROUP="rg-fastapi-webapp"
LOCATION="West Europe"
APP_SERVICE_PLAN="asp-fastapi-webapp"
WEB_APP_NAME="fastapi-webapp-$(date +%s)"  # Unique name with timestamp
STORAGE_ACCOUNT_NAME="stfastapi$(date +%s | tail -c 6)"  # Must be unique and <= 24 chars
FILE_SHARE_NAME="fastapi-data"
CONTAINER_REGISTRY_NAME=""  # Leave empty to use Docker Hub, or specify ACR name

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

check_az_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
}

check_logged_in() {
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run 'az login' first."
        exit 1
    fi
}

create_resource_group() {
    log_info "Creating resource group: $RESOURCE_GROUP"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output table
}

create_storage_account() {
    log_info "Creating storage account: $STORAGE_ACCOUNT_NAME"
    az storage account create \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --output table

    log_info "Getting storage account key..."
    STORAGE_KEY=$(az storage account keys list \
        --resource-group "$RESOURCE_GROUP" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --query '[0].value' \
        --output tsv)

    log_info "Creating file share: $FILE_SHARE_NAME"
    az storage share create \
        --name "$FILE_SHARE_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --account-key "$STORAGE_KEY" \
        --quota 1 \
        --output table
}

create_app_service_plan() {
    log_info "Creating App Service Plan: $APP_SERVICE_PLAN"
    az appservice plan create \
        --name "$APP_SERVICE_PLAN" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --is-linux \
        --sku B1 \
        --output table
}

create_web_app() {
    log_info "Creating Web App: $WEB_APP_NAME"
    az webapp create \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --plan "$APP_SERVICE_PLAN" \
        --multicontainer-config-type compose \
        --multicontainer-config-file docker-compose.yml \
        --output table

    log_info "Configuring Web App for Docker Compose..."
    
    # Enable container logging
    az webapp log config \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --docker-container-logging filesystem \
        --output table

    # Configure app settings for storage
    log_info "Configuring storage mount..."
    az webapp config storage-account add \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WEB_APP_NAME" \
        --custom-id "persistent_data" \
        --storage-type AzureFiles \
        --share-name "$FILE_SHARE_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --access-key "$STORAGE_KEY" \
        --mount-path "/data" \
        --output table

    # Set additional app settings
    az webapp config appsettings set \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings \
            WEBSITES_ENABLE_APP_SERVICE_STORAGE=true \
            WEBSITES_CONTAINER_START_TIME_LIMIT=600 \
            DOCKER_ENABLE_CI=true \
        --output table
}

deploy_docker_compose() {
    log_info "Deploying Docker Compose configuration..."
    
    # Upload docker-compose.yml to the web app
    az webapp config container set \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --multicontainer-config-type compose \
        --multicontainer-config-file docker-compose.yml \
        --output table
    
    log_info "Restarting web app to apply changes..."
    az webapp restart \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output table
}

get_deployment_info() {
    log_info "Getting deployment information..."
    
    WEB_APP_URL=$(az webapp show \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "defaultHostName" \
        --output tsv)
    
    echo
    echo "=========================================="
    echo "           DEPLOYMENT COMPLETE"
    echo "=========================================="
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Web App Name: $WEB_APP_NAME"
    echo "Web App URL: https://$WEB_APP_URL"
    echo "Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "File Share: $FILE_SHARE_NAME"
    echo
    echo "API Endpoints:"
    echo "  Health Check: https://$WEB_APP_URL/health"
    echo "  Write File: https://$WEB_APP_URL/write-file"
    echo "  List Files: https://$WEB_APP_URL/list-files"
    echo
    echo "To test the API:"
    echo "  curl -X POST \"https://$WEB_APP_URL/write-file\" \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"content\":\"Hello World!\",\"filename\":\"test.txt\"}'"
    echo "=========================================="
}

cleanup_on_error() {
    log_error "Deployment failed. You may want to clean up resources:"
    echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
}

# Main execution
main() {
    trap cleanup_on_error ERR
    
    log_info "Starting Azure infrastructure setup..."
    
    check_az_cli
    check_logged_in
    
    create_resource_group
    create_storage_account
    create_app_service_plan
    create_web_app
    deploy_docker_compose
    
    sleep 30  # Wait for deployment to settle
    get_deployment_info
    
    log_info "Setup completed successfully!"
}

# Show usage information
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Azure FastAPI Web App Setup Script"
    echo
    echo "This script creates:"
    echo "  - Resource Group"
    echo "  - Storage Account with File Share"
    echo "  - App Service Plan (Linux, B1 SKU)"
    echo "  - Web App for Containers with Docker Compose support"
    echo "  - Storage mount configuration"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in (az login)"
    echo "  - docker-compose.yml file in the current directory"
    echo
    echo "Usage: $0"
    echo "       $0 --help"
    exit 0
fi

# Run main function
main "$@"
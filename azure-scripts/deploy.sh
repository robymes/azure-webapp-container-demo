#!/bin/bash

# Deployment script for FastAPI Docker Compose application
# This script uploads the docker-compose.yml and triggers a redeployment

set -e  # Exit on any error

# Configuration - Update these with your actual values
RESOURCE_GROUP="rg-fastapi-webapp"
WEB_APP_NAME=""  # Will be prompted if not set

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

check_prerequisites() {
    # Check if docker-compose.yml exists
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in current directory"
        exit 1
    fi

    # Check if Azure CLI is installed and user is logged in
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi

    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run 'az login' first"
        exit 1
    fi
}

get_web_app_name() {
    if [[ -z "$WEB_APP_NAME" ]]; then
        echo "Available Web Apps in resource group $RESOURCE_GROUP:"
        az webapp list --resource-group "$RESOURCE_GROUP" --query "[].name" --output table
        echo
        read -p "Enter the Web App name: " WEB_APP_NAME
        
        if [[ -z "$WEB_APP_NAME" ]]; then
            log_error "Web App name cannot be empty"
            exit 1
        fi
    fi
}

verify_web_app() {
    log_info "Verifying Web App exists..."
    if ! az webapp show --name "$WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_error "Web App '$WEB_APP_NAME' not found in resource group '$RESOURCE_GROUP'"
        exit 1
    fi
}

deploy_compose() {
    log_info "Deploying docker-compose.yml to $WEB_APP_NAME..."
    
    # Update the container configuration
    az webapp config container set \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --multicontainer-config-type compose \
        --multicontainer-config-file docker-compose.yml \
        --output table
    
    log_info "Triggering deployment..."
    az webapp deployment source sync \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output table 2>/dev/null || true  # This command might not be applicable, but try anyway
    
    log_info "Restarting web app..."
    az webapp restart \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output table
}

check_deployment() {
    log_info "Waiting for deployment to complete..."
    sleep 30
    
    WEB_APP_URL=$(az webapp show \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "defaultHostName" \
        --output tsv)
    
    log_info "Testing health endpoint..."
    HEALTH_URL="https://$WEB_APP_URL/health"
    
    # Try to access the health endpoint (with timeout)
    for i in {1..10}; do
        if curl -f --max-time 30 --silent "$HEALTH_URL" > /dev/null 2>&1; then
            log_info "Health check passed!"
            break
        else
            log_warn "Health check attempt $i/10 failed, retrying in 30 seconds..."
            sleep 30
        fi
        
        if [[ $i -eq 10 ]]; then
            log_warn "Health check failed after 10 attempts. The app might still be starting."
        fi
    done
    
    echo
    echo "=========================================="
    echo "         DEPLOYMENT COMPLETE"
    echo "=========================================="
    echo "Web App URL: https://$WEB_APP_URL"
    echo "Health Check: $HEALTH_URL"
    echo
    echo "API Endpoints:"
    echo "  POST https://$WEB_APP_URL/write-file"
    echo "  GET  https://$WEB_APP_URL/list-files"
    echo "  GET  https://$WEB_APP_URL/read-file/{filename}"
    echo
    echo "Example test command:"
    echo "curl -X POST \"$HEALTH_URL\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"content\":\"Hello World!\",\"filename\":\"test.txt\"}'"
    echo "=========================================="
}

show_logs() {
    log_info "Recent application logs:"
    az webapp log tail \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" &
    
    # Let logs run for a few seconds, then stop
    sleep 10
    jobs -p | xargs -r kill 2>/dev/null || true
}

# Main execution
main() {
    log_info "Starting deployment..."
    
    check_prerequisites
    get_web_app_name
    verify_web_app
    deploy_compose
    check_deployment
    
    if [[ "${1:-}" == "--logs" ]]; then
        show_logs
    fi
    
    log_info "Deployment completed!"
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "FastAPI Docker Compose Deployment Script"
    echo
    echo "This script deploys the docker-compose.yml configuration to an existing Azure Web App."
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in"
    echo "  - docker-compose.yml file in current directory"
    echo "  - Existing Azure Web App created with setup-infrastructure.sh"
    echo
    echo "Usage: $0 [--logs]"
    echo "       $0 --help"
    echo
    echo "Options:"
    echo "  --logs    Show application logs after deployment"
    exit 0
fi

# Run main function
main "$@"
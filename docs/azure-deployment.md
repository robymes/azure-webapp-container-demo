# ☁️ Azure Deployment Documentation

This document covers Azure services configuration, deployment strategies, and management for the FastAPI Container Apps solution.

## Overview

The application deploys on Azure using a serverless container architecture with Azure Container Apps, providing automatic scaling, managed infrastructure, and integrated services.

## 🏗️ Azure Architecture

### Core Services
- **Azure Container Apps**: Serverless container hosting
- **Azure Container Registry (ACR)**: Private Docker image storage
- **Azure Storage Account**: Persistent file storage
- **Azure Files**: SMB-based persistent storage
- **Azure Resource Group**: Resource organization
- **Managed Identity**: Secure service authentication

### Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Resource Group                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │ Container Apps  │◄───┤         Storage Account         │ │
│  │   Environment   │    │  ┌─────────────────────────────┐ │ │
│  │                 │    │  │      Azure Files Share     │ │ │
│  │ ┌─────────────┐ │    │  │     (Persistent Data)      │ │ │
│  │ │ FastAPI App │ │    │  └─────────────────────────────┘ │ │
│  │ │             │ │    └──────────────────────────────────┘ │
│  │ │ /data mount │ │                    ▲                   │
│  │ └─────────────┘ │                    │                   │
│  └─────────────────┘                    │                   │
│           ▲                             │                   │
│           │                             │                   │
│  ┌─────────────────┐           ┌────────┴────────┐          │
│  │ Container       │           │ Managed Identity │          │
│  │ Registry (ACR)  │           │ (Authentication) │          │
│  │                 │           └─────────────────┘          │
│  │ Private Images  │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Deployment Options

### Option 1: Automated Full Deployment
Complete infrastructure and application deployment:

```bash
cd azure-scripts
./full-deploy.sh latest
```

**Process:**
1. Deploys Terraform infrastructure
2. Builds and pushes Docker image to ACR
3. Configures Container App with new image
4. Sets up persistent storage mounting

### Option 2: Step-by-Step Deployment

#### Step 1: Infrastructure Deployment
```bash
cd azure-scripts
./terraform-deploy.sh
```

#### Step 2: Application Deployment
```bash
./docker-build-push.sh v1.0.0
```

#### Step 3: Verification
```bash
# Get application URL
terraform output container_app_url

# Test endpoints
curl https://your-app.azurecontainerapps.io/health
```

### Option 3: Manual Deployment
For customized deployments with specific configurations:

```bash
# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan -var="location=East US" -var="container_app_cpu=1.0"

# Deploy infrastructure
terraform apply

# Build and push manually
az acr login --name $(terraform output -raw container_registry_name)
docker build -t $(terraform output -raw container_registry_login_server)/fastapi-app:custom .
docker push $(terraform output -raw container_registry_login_server)/fastapi-app:custom
```

## 🔧 Azure Container Apps Configuration

### Container App Settings
```hcl
resource "azurerm_container_app" "main" {
  name                         = var.container_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode               = "Single"

  template {
    min_replicas = var.container_app_min_replicas
    max_replicas = var.container_app_max_replicas

    container {
      name   = "fastapi-app"
      image  = "${azurerm_container_registry.main.login_server}/fastapi-app:latest"
      cpu    = var.container_app_cpu
      memory = var.container_app_memory

      env {
        name  = "PYTHONPATH"
        value = "/app"
      }

      env {
        name  = "PYTHONUNBUFFERED"
        value = "1"
      }

      volume_mounts {
        name = "azure-files-volume"
        mount_path = "/data"
      }
    }

    volume {
      name         = "azure-files-volume"
      storage_type = "AzureFile"
      storage_name = "azure-files-storage"
    }
  }
}
```

### Auto-scaling Configuration
```yaml
# Scaling rules configuration
scale:
  minReplicas: 1
  maxReplicas: 10
  rules:
  - name: "http-scaling"
    http:
      metadata:
        concurrentRequests: 100
  - name: "cpu-scaling"
    custom:
      type: "cpu"
      metadata:
        type: "Utilization"
        value: "70"
```

### Environment Variables
```bash
# Application environment
PYTHONPATH=/app
PYTHONUNBUFFERED=1

# Azure-specific (automatically set)
AZURE_CLIENT_ID=<managed-identity-client-id>
AZURE_TENANT_ID=<tenant-id>
AZURE_SUBSCRIPTION_ID=<subscription-id>
```

## 💾 Storage Configuration

### Azure Storage Account
```hcl
resource "azurerm_storage_account" "main" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  
  # Security configurations
  shared_access_key_enabled       = var.allow_shared_key_access
  infrastructure_encryption_enabled = var.enable_infrastructure_encryption
  public_network_access_enabled   = var.allow_public_network_access
  
  network_rules {
    default_action = var.enable_network_restriction ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
  }
}
```

### Azure Files Integration
```hcl
resource "azurerm_storage_share" "main" {
  name                 = "container-data"
  storage_account_name = azurerm_storage_account.main.name
  quota               = 50  # GB
  
  access_tier = "Hot"
}
```

### Storage Mount Configuration
```bash
# Container App Environment storage configuration
az containerapp env storage set \
  --name <environment-name> \
  --resource-group <resource-group> \
  --storage-name azure-files-storage \
  --azure-file-account-name <storage-account> \
  --azure-file-account-key <storage-key> \
  --azure-file-share-name container-data \
  --access-mode ReadWrite
```

## 🔒 Security Implementation

### Managed Identity Configuration
```hcl
# Container App with Managed Identity
identity {
  type = "SystemAssigned"
}

# RBAC assignments
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
```

### Network Security
```hcl
# Storage account network restrictions
network_rules {
  default_action = "Deny"
  bypass         = ["AzureServices"]
  
  # Allow specific IP ranges if needed
  ip_rules = var.allowed_ip_ranges
  
  # Virtual network rules
  virtual_network_subnet_ids = var.allowed_subnet_ids
}
```

### HTTPS Enforcement
```hcl
# Container App ingress configuration
ingress {
  allow_insecure_connections = false
  external_enabled          = true
  target_port               = 8000
  
  traffic_weight {
    percentage = 100
    latest_revision = true
  }
}
```

## 📊 Monitoring and Logging

### Application Insights Integration
```bash
# Create Application Insights
az monitor app-insights component create \
  --app fastapi-container-insights \
  --location "West Europe" \
  --resource-group <resource-group> \
  --application-type web

# Get instrumentation key
az monitor app-insights component show \
  --app fastapi-container-insights \
  --resource-group <resource-group> \
  --query instrumentationKey
```

### Log Analytics Workspace
```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_group_name}-workspace"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
```

### Container App Logs
```bash
# Real-time logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow

# Query logs with KQL
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerName_s == 'fastapi-app' | order by TimeGenerated desc"
```

## 🔄 Update and Maintenance

### Application Updates
```bash
# Build new version
./docker-build-push.sh v1.1.0

# Update Container App
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --image <acr-login-server>/fastapi-app:v1.1.0

# Monitor deployment
az containerapp revision list \
  --name <container-app-name> \
  --resource-group <resource-group>
```

### Infrastructure Updates
```bash
# Update Terraform configuration
terraform plan

# Apply changes
terraform apply

# Verify updates
terraform output
```

### Rolling Updates
```yaml
# Container App revision management
revisionMode: Single  # or Multiple for blue-green deployments

# Traffic splitting (Multiple revision mode)
traffic:
- revisionName: fastapi-app--v1-0-0
  weight: 80
- revisionName: fastapi-app--v1-1-0
  weight: 20
```

## 🌍 Multi-Region Deployment

### Primary-Secondary Setup
```hcl
# Primary region
module "primary_region" {
  source = "./modules/container-app"
  
  location = "West Europe"
  resource_group_name = "fastapi-primary"
}

# Secondary region
module "secondary_region" {
  source = "./modules/container-app"
  
  location = "East US"
  resource_group_name = "fastapi-secondary"
}
```

### Traffic Manager Integration
```hcl
resource "azurerm_traffic_manager_profile" "main" {
  name                = "fastapi-traffic-manager"
  resource_group_name = azurerm_resource_group.main.name
  
  traffic_routing_method = "Performance"
  
  dns_config {
    relative_name = "fastapi-global"
    ttl          = 60
  }
  
  monitor_config {
    protocol                     = "HTTPS"
    port                        = 443
    path                        = "/health"
    interval_in_seconds         = 30
    timeout_in_seconds          = 10
    tolerated_number_of_failures = 3
  }
}
```

## 📈 Performance Optimization

### Container App Optimization
```hcl
# Optimized resource allocation
template {
  min_replicas = 2  # Avoid cold starts
  max_replicas = 20 # Handle traffic spikes
  
  container {
    cpu    = 1.0    # Increased CPU
    memory = "2Gi"  # Increased memory
    
    # Startup and liveness probes
    startup_probe {
      http_get {
        path = "/health"
        port = 8000
      }
      initial_delay_seconds = 10
      period_seconds       = 5
    }
    
    liveness_probe {
      http_get {
        path = "/health"
        port = 8000
      }
      initial_delay_seconds = 30
      period_seconds       = 30
    }
  }
}
```

### Storage Performance
```hcl
# Premium storage for better performance
resource "azurerm_storage_account" "premium" {
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind            = "FileStorage"
  
  # Hot access tier for frequently accessed data
  access_tier = "Hot"
}
```

### CDN Integration
```hcl
resource "azurerm_cdn_profile" "main" {
  name                = "fastapi-cdn"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "main" {
  name                = "fastapi-endpoint"
  profile_name        = azurerm_cdn_profile.main.name
  location           = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  origin {
    name      = "fastapi-origin"
    host_name = azurerm_container_app.main.latest_revision_fqdn
  }
}
```

## 💰 Cost Optimization

### Resource Sizing
```bash
# Monitor resource usage
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "CpuPercentage,MemoryPercentage" \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z

# Adjust based on usage patterns
terraform apply -var="container_app_cpu=0.25" -var="container_app_memory=0.5Gi"
```

### Auto-scaling Configuration
```yaml
# Cost-optimized scaling
scale:
  minReplicas: 0    # Scale to zero during low usage
  maxReplicas: 5    # Limit maximum replicas
  rules:
  - name: "conservative-scaling"
    http:
      metadata:
        concurrentRequests: 200  # Higher threshold
```

### Storage Cost Management
```bash
# Monitor storage usage
az storage account show-usage \
  --account-name <storage-account-name>

# Configure lifecycle management
az storage account management-policy create \
  --account-name <storage-account-name> \
  --policy lifecycle-policy.json
```

## 🔍 Troubleshooting

### Common Deployment Issues

#### 1. Container App Startup Failures
```bash
# Check deployment status
az containerapp revision list \
  --name <container-app-name> \
  --resource-group <resource-group>

# View logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group>

# Check health endpoint
curl -f https://<app-url>/health
```

#### 2. Storage Mount Issues
```bash
# Verify storage configuration
az containerapp env storage list \
  --name <environment-name> \
  --resource-group <resource-group>

# Check storage account access
az storage account show \
  --name <storage-account-name> \
  --resource-group <resource-group>

# Test file operations
az storage file list \
  --account-name <storage-account-name> \
  --share-name container-data
```

#### 3. ACR Authentication Issues
```bash
# Verify Managed Identity
az containerapp identity show \
  --name <container-app-name> \
  --resource-group <resource-group>

# Check role assignments
az role assignment list \
  --assignee <managed-identity-principal-id>

# Test ACR access
az acr login --name <acr-name>
```

### Performance Issues
```bash
# Container resource usage
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "Requests,CpuPercentage,MemoryPercentage"

# Scale manually if needed
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --min-replicas 3 \
  --max-replicas 15
```

## 🔧 Advanced Configurations

### Custom Domain Setup
```bash
# Add custom domain
az containerapp hostname add \
  --hostname www.example.com \
  --name <container-app-name> \
  --resource-group <resource-group>

# Bind SSL certificate
az containerapp ssl upload \
  --certificate-file certificate.pfx \
  --certificate-password <password> \
  --name <container-app-name> \
  --resource-group <resource-group>
```

### Environment Variables Management
```bash
# Add environment variables
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --set-env-vars "DATABASE_URL=secretref:db-connection-string" "DEBUG=false"

# Use Azure Key Vault for secrets
az containerapp secret set \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --secrets "db-connection-string=keyvaultref:<key-vault-url>,identityref:<managed-identity>"
```

### Private Endpoints
```hcl
# Storage account private endpoint
resource "azurerm_private_endpoint" "storage" {
  name                = "storage-private-endpoint"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id          = azurerm_subnet.private.id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names             = ["file"]
    is_manual_connection          = false
  }
}
```

## 🔗 Related Documentation

- [Terraform Infrastructure](terraform.md)
- [Docker & Containers](docker.md)
- [Security Configuration](security.md)
- [API Documentation](api.md)
- [Troubleshooting Guide](troubleshooting.md)

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Azure Storage Documentation](https://docs.microsoft.com/en-us/azure/storage/)
- [Azure Identity and Access Management](https://docs.microsoft.com/en-us/azure/active-directory/)
# 🏗️ Terraform Infrastructure

This document covers the Terraform infrastructure setup, configuration, and management for the FastAPI Azure Container Apps deployment.

## Overview

The Terraform configuration deploys a complete Azure infrastructure including:
- Resource Group
- Azure Container Registry (ACR)
- Azure Storage Account with File Share
- Container App Environment
- Container App with auto-scaling
- Managed Identity and RBAC assignments

## 📁 Terraform Files Structure

```
azure-scripts/
├── provider.tf          # Provider configuration
├── variables.tf         # Variable definitions
├── main.tf             # Main infrastructure configuration
├── outputs.tf          # Output values
├── terraform-deploy.sh    # Deployment script
└── terraform-cleanup.sh  # Cleanup script
```

## 🚀 Quick Deployment

### Automated Deployment
```bash
cd azure-scripts
./terraform-deploy.sh
```

### Manual Deployment
```bash
cd azure-scripts

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

## 📋 Infrastructure Components

### Resource Group
- **Purpose**: Container for all Azure resources
- **Default Name**: `jkl-open-data-platform`
- **Location**: West Europe (configurable)

### Azure Container Registry (ACR)
- **SKU**: Basic (configurable)
- **Features**:
  - Private Docker image storage
  - Managed Identity integration
  - Admin user enabled for authentication
  - Same region as Container Apps for performance

### Storage Account
- **Type**: Standard LRS
- **Features**:
  - Infrastructure encryption enabled
  - Shared key access disabled (security compliance)
  - Network access restricted
  - Managed Identity authentication

### Azure File Share
- **Purpose**: Persistent storage for Container Apps
- **Mount Path**: `/data`
- **Type**: SMB-based Azure Files
- **Access**: Via Managed Identity

### Container App Environment
- **Purpose**: Managed environment for Container Apps
- **Features**:
  - Automatic scaling configuration
  - Storage mount configuration
  - Network isolation

### Container App
- **Base Image**: From private ACR
- **Scaling**:
  - Min replicas: 1 (configurable)
  - Max replicas: 5 (configurable)
  - CPU: 0.5 vCPU (configurable)
  - Memory: 1Gi (configurable)

## 🔧 Configuration Variables

### Infrastructure Variables
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "jkl-open-data-platform"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

variable "container_app_cpu" {
  description = "CPU allocation for Container App"
  type        = number
  default     = 0.5
}

variable "container_app_memory" {
  description = "Memory allocation for Container App"
  type        = string
  default     = "1Gi"
}
```

### Security Variables
```hcl
variable "enable_infrastructure_encryption" {
  description = "Enable infrastructure encryption for storage account"
  type        = bool
  default     = true
}

variable "allow_shared_key_access" {
  description = "Allow shared key access to storage account"
  type        = bool
  default     = false
}
```

## 🔒 Security Implementation

### Managed Identity
- **Type**: System-assigned Managed Identity
- **Purpose**: Secure access to ACR and Storage
- **Roles**:
  - `AcrPull` - Container Registry access
  - `Storage File Data SMB Share Contributor` - File share access

### RBAC Configuration
```hcl
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_file_data" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
```

## 📤 Terraform Outputs

Key outputs available after deployment:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output container_app_url
terraform output container_registry_name
terraform output storage_account_name
terraform output resource_group_name
```

### Available Outputs
- `container_app_url` - Public URL of the deployed application
- `container_registry_name` - ACR name for Docker operations
- `container_registry_login_server` - ACR login server URL
- `storage_account_name` - Storage account name
- `resource_group_name` - Resource group name

## 🔄 State Management

### Local State (Default)
Terraform state is stored locally in `terraform.tfstate` file.

### Remote State (Recommended for Production)
Configure Azure Storage backend:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstatestore"
    container_name       = "tfstate"
    key                 = "fastapi-webapp.terraform.tfstate"
  }
}
```

## 🔧 Common Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format configuration files
terraform fmt

# Plan changes
terraform plan

# Apply changes
terraform apply

# View current state
terraform show

# Import existing resource
terraform import azurerm_resource_group.example /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example

# Destroy infrastructure
terraform destroy
```

## 🔄 Updates and Modifications

### Infrastructure Updates
```bash
# After modifying .tf files
terraform plan
terraform apply
```

### Variable Updates
Modify `variables.tf` or create `terraform.tfvars`:

```hcl
# terraform.tfvars
resource_group_name = "my-custom-rg"
location = "East US"
container_app_cpu = 1.0
container_app_memory = "2Gi"
```

## 🧹 Resource Cleanup

### Automated Cleanup
```bash
cd azure-scripts
./terraform-cleanup.sh
```

### Manual Cleanup
```bash
terraform destroy
```

**Warning**: This will permanently delete all resources and data!

## 🐛 Troubleshooting

### Common Issues

1. **Provider Authentication**
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **State Lock Issues**
   ```bash
   terraform force-unlock <lock-id>
   ```

3. **Resource Already Exists**
   ```bash
   terraform import <resource-type>.<name> <azure-resource-id>
   ```

4. **Permission Denied**
   - Verify Azure CLI login
   - Check subscription permissions
   - Ensure proper RBAC roles

### Validation Commands
```bash
# Check Azure login
az account show

# Validate Terraform configuration
terraform validate

# Check resource group exists
az group show --name <resource-group-name>

# List Container Apps
az containerapp list --resource-group <resource-group-name>
```

## 📊 Cost Optimization

### Resource Sizing
- Adjust `container_app_cpu` and `container_app_memory` based on needs
- Configure `container_app_min_replicas` and `container_app_max_replicas`
- Use appropriate ACR SKU (Basic/Standard/Premium)

### Cost Monitoring
```bash
# View resource costs
az consumption usage list --resource-group <resource-group-name>
```

## 🔗 Related Documentation

- [Azure Deployment Guide](azure-deployment.md)
- [Security Configuration](security.md)
- [Docker & Containers](docker.md)
- [Troubleshooting Guide](troubleshooting.md)
# Simplified and Working Terraform Configuration
# This addresses all deployment issues with a step-by-step approach

# Generate random suffix for unique naming
resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Create Azure Container Registry (ACR)
resource "azurerm_container_registry" "main" {
  name                = "${var.container_registry_name_prefix}${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.container_registry_sku
  admin_enabled       = true  # Enable for initial deployment
  
  tags = var.tags
}

# Storage Account for persistent data
resource "azurerm_storage_account" "main" {
  name                            = "${var.storage_account_name_prefix}${random_integer.suffix.result}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = var.storage_account_tier
  account_replication_type        = var.storage_account_replication_type
  infrastructure_encryption_enabled = var.enable_infrastructure_encryption
  
  # Start with shared key access enabled for initial deployment, can be disabled later
  shared_access_key_enabled       = true
  public_network_access_enabled   = var.allow_public_network_access

  # Basic network rules - will be enhanced later
  network_rules {
    default_action = var.enable_network_restriction ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Azure File Share for persistent storage
resource "azurerm_storage_share" "main" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota
  access_tier          = "Hot"
}

# Create Container App Environment (simplified)
resource "azurerm_container_app_environment" "main" {
  name                = var.container_app_environment_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# Container App Environment Storage
resource "azurerm_container_app_environment_storage" "data" {
  name                         = "data-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.main.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

# Create Container App (simplified, no image initially)
resource "azurerm_container_app" "main" {
  name                         = "${var.container_app_name_prefix}-${random_integer.suffix.result}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Enable managed identity
  identity {
    type = "SystemAssigned"
  }

  template {
    min_replicas = var.container_app_min_replicas
    max_replicas = var.container_app_max_replicas

    container {
      name   = "fastapi-app"
      # Use a simple working image initially, will be updated by deployment script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
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

      # Volume mount for persistent storage
      volume_mounts {
        name = "data-volume"
        path = "/data"
      }
    }

    # Azure Files volume
    volume {
      name         = "data-volume"
      storage_type = "AzureFile"
      storage_name = "data-storage"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 80  # Will be updated to 8000 later
    transport                 = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    username = azurerm_container_registry.main.admin_username
    password_secret_name = "registry-password"
  }

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.main.admin_password
  }

  tags = var.tags
}

# RBAC Role Assignments
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_file_smb_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
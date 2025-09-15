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

# Storage Account and File Share will be created via Azure CLI post-deployment
# This completely avoids Terraform provider issues with shared key access disabled
# See terraform-deploy.sh for the complete Azure CLI implementation

# Create Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${var.container_registry_name_prefix}${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.container_registry_sku
  
  # Enable admin user for basic authentication
  admin_enabled = var.container_registry_admin_enabled
  
  # Enable managed identity access
  identity {
    type = "SystemAssigned"
  }

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
  shared_access_key_enabled       = var.allow_shared_key_access  # Security policy compliance
  public_network_access_enabled   = var.allow_public_network_access

  # Network rules to restrict access
  network_rules {
    default_action = var.enable_network_restriction ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Azure File Share for persistent storage (conditional on shared key access)
resource "azurerm_storage_share" "main" {
  count = var.allow_shared_key_access ? 1 : 0
  
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota
}

# Create Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                = var.container_app_environment_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# Container App Environment Storage for Azure Files (conditional on shared key access)
resource "azurerm_container_app_environment_storage" "data" {
  count = var.allow_shared_key_access ? 1 : 0
  
  name                         = "data-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.main[0].name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

# Create Container App
resource "azurerm_container_app" "main" {
  name                         = "${var.container_app_name_prefix}-${random_integer.suffix.result}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Enable managed identity for secure access to ACR
  identity {
    type = "SystemAssigned"
  }

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

      # Volume mount for persistent storage (conditional on shared key access)
      dynamic "volume_mounts" {
        for_each = var.allow_shared_key_access ? [1] : []
        content {
          name = "data-volume"
          path = "/data"
        }
      }
    }

    # Azure Files volume (conditional on shared key access)
    dynamic "volume" {
      for_each = var.allow_shared_key_access ? [1] : []
      content {
        name         = "data-volume"
        storage_type = "AzureFile"
        storage_name = "data-storage"
      }
    }
  }

  ingress {
    allow_insecure_connections = false  # Force HTTPS only
    external_enabled          = true
    target_port               = 8000
    transport                 = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = "system"
  }

  # Remove depends_on since storage is now conditional
  # depends_on will be handled implicitly through resource references

  tags = var.tags
}

# Role assignment to allow Container App to pull images from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

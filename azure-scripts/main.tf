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

# Create Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "${var.storage_account_name_prefix}${random_integer.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind            = "StorageV2"
  
  tags = var.tags
}

# Create File Share
resource "azurerm_storage_share" "main" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota
}

# Create App Service Plan
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  
  tags = var.tags
}

# Create Web App
resource "azurerm_linux_web_app" "main" {
  name                = "${var.web_app_name_prefix}-${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      docker_image_name   = "fastapi-app:latest"
      docker_registry_url = "https://index.docker.io"
    }
    
    # Enable container logging
    container_registry_use_managed_identity = false
  }

  # App Settings
  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = var.enable_app_service_storage
    WEBSITES_CONTAINER_START_TIME_LIMIT = var.container_start_time_limit
    DOCKER_ENABLE_CI                   = var.docker_enable_ci
    
    # Environment variables for the application
    PYTHONPATH      = "/app"
    PYTHONUNBUFFERED = "1"
  }

  # Storage configuration for persistent data
  storage_account {
    name         = "persistent_data"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.main.name
    access_key   = azurerm_storage_account.main.primary_access_key
    share_name   = azurerm_storage_share.main.name
    mount_path   = "/data"
  }

  # Enable logging
  logs {
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 100
      }
    }
  }

  tags = var.tags
}

# Configure the web app with Docker Compose (requires Azure CLI or additional configuration)
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id

  site_config {
    application_stack {
      docker_image_name   = "fastapi-app:latest"
      docker_registry_url = "https://index.docker.io"
    }
  }

  app_settings = azurerm_linux_web_app.main.app_settings

  tags = var.tags
}
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

  # Policy 3: App Service apps should only be accessible over HTTPS
  https_only = var.https_only

  # Enable managed identity for secure access to storage
  identity {
    type = "SystemAssigned"
  }

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

  # Storage configuration will be handled post-deployment via Azure CLI
  # This approach allows us to use Managed Identity without access keys
  # See deployment script or README for manual configuration steps

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

  # Policy 3: App Service apps should only be accessible over HTTPS
  https_only = var.https_only

  site_config {
    application_stack {
      docker_image_name   = "fastapi-app:latest"
      docker_registry_url = "https://index.docker.io"
    }
  }

  app_settings = azurerm_linux_web_app.main.app_settings

  tags = var.tags
}

# Role assignments for storage access will be configured post-deployment
# via Azure CLI when the storage account is created
# See terraform-deploy.sh for the complete implementation
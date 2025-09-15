terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"  # Use a more specific version that's known to work better with Container Apps
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  # Use Azure AD authentication for storage operations
  # This allows Terraform to work with storage accounts that have shared key access disabled
  storage_use_azuread = true
  
  # Skip provider registration to avoid potential polling issues
  skip_provider_registration = true
}
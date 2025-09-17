terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80" # Use a more specific version that's known to work better with Container Apps
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>1.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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

provider "azapi" {
  # Configuration will be inherited from azurerm provider
}

# Kubernetes provider configuration
# This configuration will work during the entire terraform lifecycle
provider "kubernetes" {
  host                   = try(azurerm_kubernetes_cluster.main.kube_config.0.host, "")
  client_certificate     = try(base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate), "")
  client_key            = try(base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key), "")
  cluster_ca_certificate = try(base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate), "")
}

provider "helm" {
  kubernetes {
    host                   = try(azurerm_kubernetes_cluster.main.kube_config.0.host, "")
    client_certificate     = try(base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate), "")
    client_key            = try(base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key), "")
    cluster_ca_certificate = try(base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate), "")
  }
}
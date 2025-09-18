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

# Kubernetes provider configuration using direct resource reference
# This eliminates timing issues by using the resource directly instead of a data source
provider "kubernetes" {
  host                   = var.aks_cluster_exists ? azurerm_kubernetes_cluster.main.kube_config.0.host : "https://127.0.0.1"
  client_certificate     = var.aks_cluster_exists ? base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate) : null
  client_key            = var.aks_cluster_exists ? base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key) : null
  cluster_ca_certificate = var.aks_cluster_exists ? base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate) : null
  
  # Skip TLS verification when using placeholder values
  insecure = !var.aks_cluster_exists
}

provider "helm" {
  kubernetes {
    host                   = var.aks_cluster_exists ? azurerm_kubernetes_cluster.main.kube_config.0.host : "https://127.0.0.1"
    client_certificate     = var.aks_cluster_exists ? base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate) : null
    client_key            = var.aks_cluster_exists ? base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key) : null
    cluster_ca_certificate = var.aks_cluster_exists ? base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate) : null
    
    # Skip TLS verification when using placeholder values
    insecure = !var.aks_cluster_exists
  }
}
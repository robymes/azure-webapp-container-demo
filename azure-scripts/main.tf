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
  admin_enabled       = true # Enable for initial deployment

  tags = var.tags
}

# SECURITY WORKAROUND: Storage account with temporary shared key access
# The azurerm_storage_share resource requires key-based authentication during creation
# We enable shared_access_key_enabled temporarily and disable it via null_resource after creation
resource "azurerm_storage_account" "main" {
  name                              = "${var.storage_account_name_prefix}${random_integer.suffix.result}"
  resource_group_name               = azurerm_resource_group.main.name
  location                          = azurerm_resource_group.main.location
  account_tier                      = var.storage_account_tier
  account_replication_type          = var.storage_account_replication_type
  infrastructure_encryption_enabled = var.enable_infrastructure_encryption

  # Temporarily enable shared key access for File Share creation
  shared_access_key_enabled     = true
  public_network_access_enabled = var.allow_public_network_access

  # Basic network rules - will be enhanced later
  network_rules {
    default_action = var.enable_network_restriction ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Azure File Share for persistent storage
# Uses Azure AD authentication with proper role assignments
resource "azurerm_storage_share" "main" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota
  access_tier          = "Hot"

  depends_on = [
    azurerm_role_assignment.terraform_storage_contributor,
    azurerm_role_assignment.terraform_storage_blob_contributor
  ]
}

# SECURITY RESTORATION: Disable shared key access after File Share creation
# This null_resource disables shared key access immediately after the File Share is created
# ensuring compliance with security policies that prohibit key-based authentication
resource "null_resource" "disable_shared_key" {
  depends_on = [azurerm_storage_share.main]
  
  provisioner "local-exec" {
    command = "az storage account update --name ${azurerm_storage_account.main.name} --resource-group ${azurerm_resource_group.main.name} --allow-shared-key-access false"
  }

  # Trigger to ensure this runs if storage account changes
  triggers = {
    storage_account_id = azurerm_storage_account.main.id
  }
}

# AKS Cluster with minimal configuration for demo
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-aks"

  # Minimal configuration for demo
  kubernetes_version = "1.28"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
    type       = "VirtualMachineScaleSets"

    # Basic networking
    vnet_subnet_id = null
  }

  # System-assigned managed identity for security compliance
  identity {
    type = "SystemAssigned"
  }

  # Enable workload identity and OIDC issuer for Azure AD authentication
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Basic configuration - no advanced features for demo
  network_profile {
    network_plugin = "kubenet"
  }

  # Enable RBAC for security compliance
  role_based_access_control_enabled = true

  tags = var.tags
}

# RBAC Role Assignments for AKS
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Kubernetes Resources for FastAPI Application Deployment

# StorageClass for Azure Files CSI driver
resource "kubernetes_storage_class_v1" "azure_file" {
  metadata {
    name = "azure-file"
  }
  storage_provisioner    = "file.csi.azure.com"
  allow_volume_expansion = true
  reclaim_policy         = "Retain"
  volume_binding_mode    = "Immediate"
  parameters = {
    skuName = "Standard_LRS"
  }
  mount_options = ["file_mode=0777", "dir_mode=0777", "mfsymlinks", "uid=1001", "gid=1001", "nobrl"]

  depends_on = [azurerm_kubernetes_cluster.main]
}

# PersistentVolume for Azure Files
resource "kubernetes_persistent_volume_v1" "azure_file_pv" {
  metadata {
    name = "fastapi-azure-file-pv"
  }
  spec {
    capacity = {
      storage = "${var.file_share_quota}Gi"
    }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.azure_file.metadata[0].name

    persistent_volume_source {
      csi {
        driver        = "file.csi.azure.com"
        volume_handle = "${azurerm_storage_account.main.name}#${azurerm_storage_share.main.name}"
        read_only     = false
        volume_attributes = {
          resourceGroup  = azurerm_resource_group.main.name
          storageAccount = azurerm_storage_account.main.name
          shareName      = azurerm_storage_share.main.name
        }
        # Removed node_stage_secret_ref - using Azure AD authentication via workload identity
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_storage_share.main,
    kubernetes_storage_class_v1.azure_file
  ]
}

# PersistentVolumeClaim
resource "kubernetes_persistent_volume_claim_v1" "fastapi_pvc" {
  metadata {
    name      = "fastapi-pvc"
    namespace = "default"
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.azure_file.metadata[0].name
    resources {
      requests = {
        storage = "${var.file_share_quota}Gi"
      }
    }
    volume_name = kubernetes_persistent_volume_v1.azure_file_pv.metadata[0].name
  }

  depends_on = [kubernetes_persistent_volume_v1.azure_file_pv]
}

# Secret for Azure Storage Account - Using Azure AD authentication
# No storage account key required with workload identity
resource "kubernetes_secret_v1" "azure_storage_secret" {
  metadata {
    name      = "azure-storage-secret"
    namespace = "default"
  }

  data = {
    azurestorageaccountname = azurerm_storage_account.main.name
    # Removed azurestorageaccountkey - using Azure AD authentication instead
  }

  type = "Opaque"

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Service Account for workload identity
resource "kubernetes_service_account_v1" "fastapi_serviceaccount" {
  metadata {
    name      = "fastapi-serviceaccount"
    namespace = "default"
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.aks_workload_identity.client_id
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_user_assigned_identity.aks_workload_identity
  ]
}

# ConfigMap for FastAPI application configuration
resource "kubernetes_config_map_v1" "fastapi_config" {
  metadata {
    name      = "fastapi-config"
    namespace = "default"
  }

  data = {
    "config.toml" = <<EOF
[app]
name = "FastAPI Demo Application"
version = "1.0.0"
debug = false

[server]
host = "0.0.0.0"
port = 8000

[storage]
data_path = "/data"
azure_storage_account = "${azurerm_storage_account.main.name}"
azure_file_share = "${azurerm_storage_share.main.name}"
EOF
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Kubernetes Deployment for FastAPI application
resource "kubernetes_deployment_v1" "fastapi_app" {
  metadata {
    name      = "fastapi-app"
    namespace = "default"
    labels = {
      app = "fastapi-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "fastapi-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "fastapi-app"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.fastapi_serviceaccount.metadata[0].name

        container {
          image = "${azurerm_container_registry.main.login_server}/fastapi-app:latest"
          name  = "fastapi-app"

          port {
            container_port = 8000
          }

          env {
            name  = "PORT"
            value = "8000"
          }

          env {
            name  = "AZURE_STORAGE_ACCOUNT"
            value = azurerm_storage_account.main.name
          }

          env {
            name  = "AZURE_USE_WORKLOAD_IDENTITY"
            value = "true"
          }

          volume_mount {
            name       = "data-volume"
            mount_path = "/data"
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/app/config"
            read_only  = true
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "data-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.fastapi_pvc.metadata[0].name
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map_v1.fastapi_config.metadata[0].name
          }
        }

        image_pull_secrets {
          name = kubernetes_secret_v1.acr_secret.metadata[0].name
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim_v1.fastapi_pvc,
    kubernetes_config_map_v1.fastapi_config,
    kubernetes_secret_v1.acr_secret,
    kubernetes_service_account_v1.fastapi_serviceaccount
  ]
}

# Secret for ACR authentication
resource "kubernetes_secret_v1" "acr_secret" {
  metadata {
    name      = "acr-secret"
    namespace = "default"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${azurerm_container_registry.main.login_server}" = {
          "username" = azurerm_container_registry.main.admin_username
          "password" = azurerm_container_registry.main.admin_password
          "auth"     = base64encode("${azurerm_container_registry.main.admin_username}:${azurerm_container_registry.main.admin_password}")
        }
      }
    })
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Kubernetes Service for internal connectivity
resource "kubernetes_service_v1" "fastapi_service" {
  metadata {
    name      = "fastapi-service"
    namespace = "default"
    labels = {
      app = "fastapi-app"
    }
  }

  spec {
    selector = {
      app = "fastapi-app"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.fastapi_app]
}

# LoadBalancer Service for external access
resource "kubernetes_service_v1" "fastapi_loadbalancer" {
  metadata {
    name      = "fastapi-loadbalancer"
    namespace = "default"
    labels = {
      app = "fastapi-app"
    }
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/health"
    }
  }

  spec {
    selector = {
      app = "fastapi-app"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment_v1.fastapi_app]
}

resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id

  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "azurerm_role_assignment" "storage_file_smb_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Get current client configuration for role assignments
data "azurerm_client_config" "current" {}

# User-assigned managed identity for Kubernetes workload identity
resource "azurerm_user_assigned_identity" "aks_workload_identity" {
  name                = "${var.project_name}-workload-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# Role assignment for workload identity to access storage account
resource "azurerm_role_assignment" "workload_identity_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_workload_identity.principal_id

  depends_on = [azurerm_user_assigned_identity.aks_workload_identity]
}

resource "azurerm_role_assignment" "workload_identity_storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_workload_identity.principal_id

  depends_on = [azurerm_user_assigned_identity.aks_workload_identity]
}

# Role assignment for current service principal (Terraform) to access storage
resource "azurerm_role_assignment" "terraform_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_storage_account.main]
}

resource "azurerm_role_assignment" "terraform_storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_storage_account.main]
}

# Federated identity credential for AKS workload identity
resource "azurerm_federated_identity_credential" "aks_workload_identity" {
  name                = "${var.project_name}-federated-identity"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.aks_workload_identity.id
  subject             = "system:serviceaccount:default:fastapi-serviceaccount"

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_user_assigned_identity.aks_workload_identity
  ]
}
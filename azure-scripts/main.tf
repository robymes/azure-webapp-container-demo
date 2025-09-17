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
  sku                 = "Premium" # Required for private endpoints
  admin_enabled       = false # Security compliance - no admin access

  # Disable public network access for security
  public_network_access_enabled = false

  tags = var.tags
}

# Storage account with security compliance - no shared key access
resource "azurerm_storage_account" "main" {
  name                              = "${var.storage_account_name_prefix}${random_integer.suffix.result}"
  resource_group_name               = azurerm_resource_group.main.name
  location                          = azurerm_resource_group.main.location
  account_tier                      = var.storage_account_tier
  account_replication_type          = var.storage_account_replication_type
  infrastructure_encryption_enabled = var.enable_infrastructure_encryption

  # Security compliance - disable shared key access
  shared_access_key_enabled     = false
  public_network_access_enabled = false

  # Network rules for security compliance
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Azure File Share for persistent storage using AzAPI provider for Azure AD authentication
resource "azapi_resource" "main" {
  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01"
  name      = var.file_share_name
  parent_id = "${azurerm_storage_account.main.id}/fileServices/default"

  body = jsonencode({
    properties = {
      shareQuota  = var.file_share_quota
      accessTier  = "Hot"
      metadata    = {}
    }
  })

  depends_on = [
    azurerm_role_assignment.terraform_storage_contributor,
    azurerm_role_assignment.terraform_storage_blob_contributor
  ]
}

# Virtual Network for private endpoints
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = [var.vnet_address_space[0]]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "${var.project_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefix
}

# Subnet for private endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.project_name}-pe-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.private_endpoint_subnet_address_prefix
}

# AKS Cluster with minimal configuration for demo
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-aks"

  # Minimal configuration for demo
  # Using default supported kubernetes version (removed specific version to avoid LTS compatibility issues)

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
    type       = "VirtualMachineScaleSets"

    # Enable host encryption for security compliance
    enable_host_encryption = true

    # Use private subnet
    vnet_subnet_id = azurerm_subnet.aks.id
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
    network_plugin      = "kubenet"
    service_cidr        = var.aks_service_cidr
    dns_service_ip      = var.aks_dns_service_ip
  }

  # Enable RBAC for security compliance
  role_based_access_control_enabled = true

  tags = var.tags
}

# RBAC Role Assignments for AKS (moved to end of file with private endpoints)

# Kubernetes Resources for FastAPI Application Deployment

# Null resource to ensure AKS cluster is fully ready before creating Kubernetes resources
resource "null_resource" "wait_for_aks" {
  provisioner "local-exec" {
    command = "sleep 30"  # Wait 30 seconds for AKS to be fully ready
  }
  
  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_role_assignment.storage_file_smb_contributor,
    azurerm_role_assignment.aks_acr_pull
  ]
}

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
    skuName              = "Standard_LRS"
    storageAccount       = azurerm_storage_account.main.name
    resourceGroup        = azurerm_resource_group.main.name
    # Use managed identity for secure access
    useDataPlaneAPI      = "true"
  }
  mount_options = ["file_mode=0777", "dir_mode=0777", "mfsymlinks", "uid=1001", "gid=1001", "nobrl"]

  depends_on = [
    null_resource.wait_for_aks,
    azurerm_storage_account.main,
    azurerm_role_assignment.storage_file_smb_contributor
  ]
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
        volume_handle = "${azurerm_storage_account.main.name}#${azapi_resource.main.name}"
        read_only     = false
        volume_attributes = {
          resourceGroup  = azurerm_resource_group.main.name
          storageAccount = azurerm_storage_account.main.name
          shareName      = azapi_resource.main.name
        }
        # Removed node_stage_secret_ref - using Azure AD authentication via workload identity
      }
    }
  }

  depends_on = [
    null_resource.wait_for_aks,
    azapi_resource.main,
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

  depends_on = [null_resource.wait_for_aks]
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
    null_resource.wait_for_aks,
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
azure_file_share = "${azapi_resource.main.name}"
EOF
  }

  depends_on = [null_resource.wait_for_aks]
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

        # No image_pull_secrets needed - AKS uses managed identity for ACR access
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim_v1.fastapi_pvc,
    kubernetes_config_map_v1.fastapi_config,
    kubernetes_service_account_v1.fastapi_serviceaccount
  ]
}

# No ACR secret needed - using managed identity integration
# AKS will automatically authenticate to ACR using the kubelet managed identity

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

# Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Private DNS Zone for Container Registry
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Link DNS zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "${var.project_name}-storage-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "${var.project_name}-acr-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = var.tags
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage" {
  name                = "${var.project_name}-storage-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.project_name}-storage-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }

  tags = var.tags
}

# Private Endpoint for Container Registry
resource "azurerm_private_endpoint" "acr" {
  name                = "${var.project_name}-acr-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.project_name}-acr-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = var.tags
}

# Role assignment for AKS to pull from ACR using managed identity
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id

  depends_on = [azurerm_kubernetes_cluster.main]
}
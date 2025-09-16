output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Container Registry outputs
output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the container registry"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "Admin password for the container registry"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

# Storage account and file share outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "file_share_name" {
  description = "Name of the file share for persistent storage"
  value       = var.file_share_name
}

# AKS outputs
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_cluster_kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "aks_cluster_node_resource_group" {
  description = "The auto-generated Resource Group which contains the resources for this Managed Kubernetes Cluster"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

# Storage and networking outputs

output "managed_identity_principal_id" {
  description = "Principal ID of the AKS cluster's managed identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
  sensitive   = true
}

# External Access Information
output "external_access_info" {
  description = "Information for external access to Azure Files"
  value = {
    storage_account_name = azurerm_storage_account.main.name
    file_share_name      = var.file_share_name
    resource_group_name  = azurerm_resource_group.main.name
    access_method        = "Azure AD Authentication (Managed Identity)"
    script_path          = "./external-storage-access.sh"
    authentication_note  = "No shared keys required - uses Azure AD"
  }
}

# Security Configuration Summary
output "security_configuration" {
  description = "Summary of security configuration"
  value = {
    shared_key_access_enabled = var.allow_shared_key_access
    infrastructure_encryption = var.enable_infrastructure_encryption
    managed_identity_auth     = true
    external_storage_access   = true
  }
}

output "deployment_info" {
  description = "Complete deployment information"
  value = {
    resource_group         = azurerm_resource_group.main.name
    location               = azurerm_resource_group.main.location
    aks_cluster_name       = azurerm_kubernetes_cluster.main.name
    aks_cluster_fqdn       = azurerm_kubernetes_cluster.main.fqdn
    storage_account        = azurerm_storage_account.main.name
    file_share             = var.file_share_name
    container_registry     = azurerm_container_registry.main.name
    container_registry_url = azurerm_container_registry.main.login_server
    docker_image           = "${azurerm_container_registry.main.login_server}/fastapi-app:latest"
  }
}

# Kubernetes Application Access Information
output "application_access" {
  description = "External access information for the FastAPI application"
  value = {
    loadbalancer_service = kubernetes_service_v1.fastapi_loadbalancer.metadata[0].name
    external_ip_note     = "Run 'kubectl get svc fastapi-loadbalancer' to get the external IP"
    kubectl_command      = "kubectl get svc fastapi-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
    application_url      = "http://<EXTERNAL_IP>"
    health_check_url     = "http://<EXTERNAL_IP>/health"
  }
}

# Azure AD Authentication and Workload Identity outputs
output "workload_identity_client_id" {
  description = "Client ID of the user-assigned managed identity for workload identity"
  value       = azurerm_user_assigned_identity.aks_workload_identity.client_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "azure_location" {
  description = "Azure location for resources"
  value       = azurerm_resource_group.main.location
}

# Updated ACR name output for convenience
output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

# Kubernetes Configuration Summary
output "kubernetes_deployment_summary" {
  description = "Summary of Kubernetes resources deployed"
  value = {
    deployment_name         = kubernetes_deployment_v1.fastapi_app.metadata[0].name
    service_name            = kubernetes_service_v1.fastapi_service.metadata[0].name
    loadbalancer_service    = kubernetes_service_v1.fastapi_loadbalancer.metadata[0].name
    persistent_volume_claim = kubernetes_persistent_volume_claim_v1.fastapi_pvc.metadata[0].name
    config_map              = kubernetes_config_map_v1.fastapi_config.metadata[0].name
    storage_class           = kubernetes_storage_class_v1.azure_file.metadata[0].name
    replicas                = kubernetes_deployment_v1.fastapi_app.spec[0].replicas
    container_image         = "${azurerm_container_registry.main.login_server}/fastapi-app:latest"
    data_mount_path         = "/data"
  }
}
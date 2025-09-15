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
  description = "Name of the file share (only when shared key access is enabled)"
  value       = var.allow_shared_key_access ? azurerm_storage_share.main[0].name : "N/A - Shared key access disabled"
}

# Container Apps outputs
output "container_app_environment_name" {
  description = "Name of the Container App Environment"
  value       = azurerm_container_app_environment.main.name
}

output "container_app_name" {
  description = "Name of the created container app"
  value       = azurerm_container_app.main.name
}

output "container_app_url" {
  description = "URL of the deployed container app"
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "container_app_fqdn" {
  description = "FQDN of the container app"
  value       = azurerm_container_app.main.ingress[0].fqdn
}

output "api_endpoints" {
  description = "Available API endpoints"
  value = {
    health_check = "https://${azurerm_container_app.main.ingress[0].fqdn}/health"
    write_file   = "https://${azurerm_container_app.main.ingress[0].fqdn}/write-file"
    list_files   = "https://${azurerm_container_app.main.ingress[0].fqdn}/list-files"
    init_dwh     = "https://${azurerm_container_app.main.ingress[0].fqdn}/init-dwh"
    query        = "https://${azurerm_container_app.main.ingress[0].fqdn}/query"
  }
}

output "deployment_info" {
  description = "Complete deployment information"
  value = {
    resource_group             = azurerm_resource_group.main.name
    location                  = azurerm_resource_group.main.location
    container_app_name        = azurerm_container_app.main.name
    container_app_url         = "https://${azurerm_container_app.main.ingress[0].fqdn}"
    container_app_environment = azurerm_container_app_environment.main.name
    storage_account           = azurerm_storage_account.main.name
    file_share                = var.allow_shared_key_access ? azurerm_storage_share.main[0].name : "N/A - Shared key access disabled"
    container_registry        = azurerm_container_registry.main.name
    container_registry_url    = azurerm_container_registry.main.login_server
    docker_image              = "${azurerm_container_registry.main.login_server}/fastapi-app:latest"
  }
}
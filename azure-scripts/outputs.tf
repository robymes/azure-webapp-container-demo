output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Storage account and file share outputs (created via Azure CLI)
output "storage_account_name" {
  description = "Name of the storage account (created via Azure CLI)"
  value       = "${var.storage_account_name_prefix}${random_integer.suffix.result}"
}

output "file_share_name" {
  description = "Name of the file share (created via Azure CLI)"
  value       = var.file_share_name
}

output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}

output "web_app_name" {
  description = "Name of the created web app"
  value       = azurerm_linux_web_app.main.name
}

output "web_app_url" {
  description = "URL of the deployed web app"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "web_app_default_hostname" {
  description = "Default hostname of the web app"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "api_endpoints" {
  description = "Available API endpoints"
  value = {
    health_check = "https://${azurerm_linux_web_app.main.default_hostname}/health"
    write_file   = "https://${azurerm_linux_web_app.main.default_hostname}/write-file"
    list_files   = "https://${azurerm_linux_web_app.main.default_hostname}/list-files"
  }
}

output "deployment_info" {
  description = "Complete deployment information"
  value = {
    resource_group      = azurerm_resource_group.main.name
    location           = azurerm_resource_group.main.location
    web_app_name       = azurerm_linux_web_app.main.name
    web_app_url        = "https://${azurerm_linux_web_app.main.default_hostname}"
    storage_account    = "${var.storage_account_name_prefix}${random_integer.suffix.result}"
    file_share         = var.file_share_name
    app_service_plan   = azurerm_service_plan.main.name
  }
}
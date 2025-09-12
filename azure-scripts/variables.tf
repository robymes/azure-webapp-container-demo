variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-fastapi-webapp"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "asp-fastapi-webapp"
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
}

variable "web_app_name_prefix" {
  description = "Prefix for the Web App name (timestamp will be appended)"
  type        = string
  default     = "fastapi-webapp"
}

variable "storage_account_name_prefix" {
  description = "Prefix for the Storage Account name (random suffix will be appended)"
  type        = string
  default     = "stfastapi"
}

variable "file_share_name" {
  description = "Name of the Azure File Share"
  type        = string
  default     = "fastapi-data"
}

variable "file_share_quota" {
  description = "Quota for the Azure File Share in GB"
  type        = number
  default     = 1
}

variable "storage_account_tier" {
  description = "Performance tier of the storage account"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Replication type for the storage account"
  type        = string
  default     = "LRS"
}

variable "container_start_time_limit" {
  description = "Container start time limit in seconds"
  type        = number
  default     = 600
}

variable "enable_app_service_storage" {
  description = "Enable App Service storage"
  type        = bool
  default     = true
}

variable "docker_enable_ci" {
  description = "Enable Docker CI"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "FastAPI-WebApp"
    ManagedBy   = "Terraform"
  }
}
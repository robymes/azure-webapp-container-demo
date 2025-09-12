variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "jkl-open-data-platform"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "jkl-odp-fastapi-plan"
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
}

variable "web_app_name_prefix" {
  description = "Prefix for the Web App name (timestamp will be appended)"
  type        = string
  default     = "jkl-odp-fastapi-webapp"
}

variable "storage_account_name_prefix" {
  description = "Prefix for the Storage Account name (random suffix will be appended)"
  type        = string
  default     = "jklodpstg"
}

variable "file_share_name" {
  description = "Name of the Azure File Share"
  type        = string
  default     = "jkl-odp-fileshare"
}

variable "file_share_quota" {
  description = "Quota for the Azure File Share in GB"
  type        = number
  default     = 3
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
    Project     = "J-ODP"
    ManagedBy   = "Terraform"
  }
}

variable "enable_infrastructure_encryption" {
  description = "Enable infrastructure encryption for storage account"
  type        = bool
  default     = true
}

variable "allow_shared_key_access" {
  description = "Allow shared key access to storage account"
  type        = bool
  default     = false
}
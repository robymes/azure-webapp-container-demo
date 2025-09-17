variable "project_name" {
  description = "Name of the project (used for AKS cluster naming)"
  type        = string
  default     = "jkl-odp"
}

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


variable "container_registry_name_prefix" {
  description = "Prefix for the Azure Container Registry name (random suffix will be appended)"
  type        = string
  default     = "jklodpacr"
}

variable "container_registry_sku" {
  description = "SKU for the Azure Container Registry"
  type        = string
  default     = "Premium"
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
  description = "Allow shared key access to storage account. Set to false for security policy compliance."
  type        = bool
  default     = false
}

variable "allow_public_network_access" {
  description = "Allow public network access to storage account. Set to false for security compliance."
  type        = bool
  default     = false
}

variable "enable_network_restriction" {
  description = "Enable network access restrictions with Azure Services bypass for security compliance"
  type        = bool
  default     = true
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_endpoint_subnet_address_prefix" {
  description = "Address prefix for the private endpoints subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "aks_service_cidr" {
  description = "CIDR block for AKS services"
  type        = string
  default     = "172.16.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "IP address for AKS DNS service (must be within service CIDR)"
  type        = string
  default     = "172.16.0.10"
}


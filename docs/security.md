# 🔒 Security & Configuration Documentation

This document covers Azure security policies, authentication mechanisms, configuration management, and security best practices for the FastAPI Container Apps deployment.

## Overview

The application implements comprehensive security measures including Azure security policy compliance, Managed Identity authentication, infrastructure encryption, and network restrictions.

## 🛡️ Azure Security Policies Implementation

### 1. Storage Accounts Prevent Shared Key Access
**Policy Enforcement**: Eliminates shared key authentication vulnerabilities

```hcl
# Terraform configuration
resource "azurerm_storage_account" "main" {
  shared_access_key_enabled = false  # Enforced by default
  
  # Alternative authentication methods
  # - Managed Identity (recommended)
  # - Azure AD authentication
  # - SAS tokens with limited scope
}
```

**Implementation Benefits**:
- Eliminates risk of compromised access keys
- Forces use of Azure AD-based authentication
- Enables granular RBAC permissions
- Provides audit trail for all access

**Configuration Variable**:
```hcl
variable "allow_shared_key_access" {
  description = "Allow shared key access to storage account"
  type        = bool
  default     = false  # Security compliance default
}
```

### 2. Storage Infrastructure Encryption
**Policy Enforcement**: Double encryption for data at rest

```hcl
resource "azurerm_storage_account" "main" {
  infrastructure_encryption_enabled = true
  
  # Provides two layers of encryption:
  # 1. Service-level encryption (always enabled)
  # 2. Infrastructure-level encryption (additional layer)
}
```

**Encryption Details**:
- **Service Encryption**: AES-256 encryption at service level
- **Infrastructure Encryption**: Additional hardware-level encryption
- **Key Management**: Microsoft-managed keys (default) or customer-managed keys
- **Compliance**: Meets enterprise security requirements

### 3. HTTPS-Only Access
**Policy Enforcement**: Forces encrypted communication

```hcl
resource "azurerm_container_app" "main" {
  ingress {
    allow_insecure_connections = false  # HTTPS only
    external_enabled          = true
    target_port               = 8000
  }
}
```

**Security Benefits**:
- Prevents data interception
- Ensures encrypted client-server communication
- Complies with data protection regulations
- Automatic HTTP to HTTPS redirection

## 🔐 Authentication & Authorization

### Managed Identity Configuration

#### System-Assigned Managed Identity
```hcl
resource "azurerm_container_app" "main" {
  identity {
    type = "SystemAssigned"
  }
}

# Automatically provides:
# - Unique identity tied to the resource lifecycle
# - Automatic credential management
# - Azure AD token acquisition
# - No stored credentials
```

#### User-Assigned Managed Identity (Alternative)
```hcl
resource "azurerm_user_assigned_identity" "main" {
  name                = "fastapi-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_container_app" "main" {
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }
}
```

### RBAC Role Assignments

#### Container Registry Access
```hcl
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
```

**Permissions Granted**:
- Pull Docker images from ACR
- Read repository metadata
- List repositories and tags

#### Storage Access
```hcl
resource "azurerm_role_assignment" "storage_file_data" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
```

**Permissions Granted**:
- Read and write files to Azure Files share
- Create and delete files and directories
- Modify file and directory permissions

### Custom RBAC Roles
```hcl
resource "azurerm_role_definition" "fastapi_custom" {
  name  = "FastAPI Custom Role"
  scope = azurerm_resource_group.main.id

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/read",
      "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/write",
      "Microsoft.ContainerRegistry/registries/pull/read"
    ]
    
    not_actions = [
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.Storage/storageAccounts/write"
    ]
  }
  
  assignable_scopes = [
    azurerm_resource_group.main.id
  ]
}
```

## 🌐 Network Security

### Storage Account Network Restrictions
```hcl
resource "azurerm_storage_account" "main" {
  public_network_access_enabled = false
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    # Allow specific IP ranges
    ip_rules = var.allowed_ip_ranges
    
    # Allow specific virtual networks
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
}
```

### Container Apps Network Configuration
```hcl
resource "azurerm_container_app_environment" "main" {
  # Internal-only environment (optional)
  internal_load_balancer_enabled = var.use_internal_load_balancer
  
  # Custom VNet integration
  infrastructure_subnet_id = var.container_apps_subnet_id
}
```

### Private Endpoints
```hcl
resource "azurerm_private_endpoint" "storage" {
  name                = "storage-private-endpoint"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id          = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "storage-private-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names             = ["file"]
    is_manual_connection          = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }
}
```

## 🔧 Configuration Management

### Environment Variables Security
```bash
# Public environment variables (safe to expose)
PYTHONPATH=/app
PYTHONUNBUFFERED=1
LOG_LEVEL=INFO

# Secret environment variables (use Azure Key Vault)
DATABASE_CONNECTION_STRING=secretref:db-connection
API_SECRET_KEY=secretref:api-secret
STORAGE_ACCOUNT_KEY=secretref:storage-key
```

### Azure Key Vault Integration
```hcl
resource "azurerm_key_vault" "main" {
  name                = "fastapi-keyvault"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id          = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_container_app.main.identity[0].principal_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }
}

resource "azurerm_key_vault_secret" "database_connection" {
  name         = "database-connection-string"
  value        = var.database_connection_string
  key_vault_id = azurerm_key_vault.main.id
}
```

### Container App Secrets Configuration
```bash
# Add secrets to Container App
az containerapp secret set \
  --name fastapi-app \
  --resource-group fastapi-rg \
  --secrets "db-connection=keyvaultref:https://fastapi-keyvault.vault.azure.net/secrets/database-connection-string,identityref:/subscriptions/.../managedIdentities/fastapi-identity"

# Reference secrets in environment variables
az containerapp update \
  --name fastapi-app \
  --resource-group fastapi-rg \
  --set-env-vars "DATABASE_URL=secretref:db-connection"
```

### TOML Configuration Security
```toml
# config.toml - Non-sensitive configuration
[database]
ducklake_path = "/data/ecommerce_analytics.ducklake"
data_path = "/data/lakehouse/"

[analytics]
top_countries_limit = 10
cache_timeout = 300

# Sensitive values should use environment variables
[security]
api_key = "${API_SECRET_KEY}"  # From environment/Key Vault
database_password = "${DB_PASSWORD}"  # From environment/Key Vault
```

## 🔍 Security Monitoring

### Azure Security Center Integration
```bash
# Enable Security Center for the subscription
az security auto-provisioning-setting update \
  --name default \
  --auto-provision on

# Configure security policies
az policy assignment create \
  --name "FastAPI Security Policy" \
  --policy "/providers/Microsoft.Authorization/policySetDefinitions/storage-security-baseline" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/fastapi-rg"
```

### Log Analytics Security Events
```hcl
resource "azurerm_log_analytics_workspace" "security" {
  name                = "fastapi-security-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                = "PerGB2018"
  retention_in_days   = 90

  # Security-specific configuration
  daily_quota_gb = 10
}

resource "azurerm_log_analytics_solution" "security" {
  solution_name         = "Security"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  workspace_resource_id = azurerm_log_analytics_workspace.security.id
  workspace_name        = azurerm_log_analytics_workspace.security.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }
}
```

### Security Alerts Configuration
```json
{
  "alertRules": [
    {
      "name": "Failed Authentication Attempts",
      "query": "SecurityEvent | where EventID == 4625 | summarize count() by Account | where count_ > 10",
      "frequency": "PT5M",
      "timeWindow": "PT15M",
      "severity": "High"
    },
    {
      "name": "Unusual Storage Access",
      "query": "StorageFileLogs | where StatusCode >= 400 | summarize count() by CallerIpAddress | where count_ > 50",
      "frequency": "PT10M",
      "timeWindow": "PT30M",
      "severity": "Medium"
    }
  ]
}
```

## 🔐 Data Protection

### Encryption in Transit
```yaml
# Container App ingress configuration
ingress:
  external: true
  allowInsecure: false  # Forces HTTPS
  targetPort: 8000
  transport: Http2      # HTTP/2 for better security
  clientCertificateMode: Require  # Optional: Require client certificates
```

### Encryption at Rest
```hcl
# Storage account encryption configuration
resource "azurerm_storage_account" "main" {
  # Service-side encryption (always enabled)
  # Infrastructure encryption (additional layer)
  infrastructure_encryption_enabled = true
  
  # Customer-managed keys (optional)
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }
}
```

### Database Encryption
```python
# DuckDB encryption configuration
import duckdb

# Connect with encryption (if available)
conn = duckdb.connect("/data/encrypted_database.db")

# Enable encryption extension
conn.execute("INSTALL encryption;")
conn.execute("LOAD encryption;")

# Set encryption key from environment
encryption_key = os.getenv("DATABASE_ENCRYPTION_KEY")
conn.execute(f"PRAGMA key='{encryption_key}';")
```

## 🛠️ Security Configuration Variables

### Terraform Security Variables
```hcl
# Security policy compliance
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

variable "allow_public_network_access" {
  description = "Allow public network access to storage account"
  type        = bool
  default     = false
}

variable "enable_network_restriction" {
  description = "Enable network access restrictions"
  type        = bool
  default     = true
}

# Network security
variable "allowed_ip_ranges" {
  description = "List of allowed IP ranges for storage access"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of allowed subnet IDs for storage access"
  type        = list(string)
  default     = []
}

# Container Apps security
variable "use_internal_load_balancer" {
  description = "Use internal load balancer for Container Apps"
  type        = bool
  default     = false
}

variable "container_apps_subnet_id" {
  description = "Subnet ID for Container Apps infrastructure"
  type        = string
  default     = null
}
```

### Environment-Specific Configurations

#### Development Environment
```hcl
# terraform.tfvars.dev
allow_shared_key_access = true   # For development convenience
allow_public_network_access = true
enable_network_restriction = false
use_internal_load_balancer = false
```

#### Production Environment
```hcl
# terraform.tfvars.prod
allow_shared_key_access = false  # Strict security
allow_public_network_access = false
enable_network_restriction = true
use_internal_load_balancer = true
allowed_ip_ranges = ["10.0.0.0/8", "172.16.0.0/12"]
```

## 🔍 Security Auditing

### Azure Policy Compliance
```bash
# Check policy compliance
az policy state list \
  --resource-group fastapi-rg \
  --query "[?complianceState=='NonCompliant']" \
  --output table

# View policy assignment details
az policy assignment list \
  --scope "/subscriptions/<subscription-id>/resourceGroups/fastapi-rg" \
  --output table
```

### Security Scan Commands
```bash
# Check storage account security
az storage account show \
  --name <storage-account-name> \
  --resource-group <resource-group> \
  --query "{SharedKeyAccess:allowSharedKeyAccess,InfraEncryption:encryptionKeyVaultProperties,NetworkAccess:publicNetworkAccess}"

# Verify Container App security
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "{Ingress:configuration.ingress.allowInsecure,Identity:identity.type}"

# Check RBAC assignments
az role assignment list \
  --assignee <managed-identity-principal-id> \
  --output table
```

### Security Assessment Script
```bash
#!/bin/bash
# security-assessment.sh

echo "=== FastAPI Security Assessment ==="

# Check resource group
RG_NAME=$(terraform output -raw resource_group_name)
echo "Resource Group: $RG_NAME"

# Check storage account security
STORAGE_NAME=$(terraform output -raw storage_account_name)
echo "Storage Account Security:"
az storage account show \
  --name $STORAGE_NAME \
  --resource-group $RG_NAME \
  --query "{SharedKeyEnabled:allowSharedKeyAccess,InfraEncryptionEnabled:encryptionKeyVaultProperties,PublicAccess:publicNetworkAccess}" \
  --output table

# Check Container App security
APP_NAME=$(terraform output -raw container_app_name)
echo "Container App Security:"
az containerapp show \
  --name $APP_NAME \
  --resource-group $RG_NAME \
  --query "{HTTPSOnly:!configuration.ingress.allowInsecure,ManagedIdentity:identity.type}" \
  --output table

# Check role assignments
IDENTITY_ID=$(az containerapp identity show --name $APP_NAME --resource-group $RG_NAME --query principalId -o tsv)
echo "RBAC Assignments:"
az role assignment list \
  --assignee $IDENTITY_ID \
  --query "[].{Role:roleDefinitionName,Scope:scope}" \
  --output table

echo "=== Assessment Complete ==="
```

## 🔧 Security Hardening Checklist

### Infrastructure Security
- [ ] Infrastructure encryption enabled
- [ ] Shared key access disabled
- [ ] Network access restrictions configured
- [ ] HTTPS-only access enforced
- [ ] Managed Identity configured
- [ ] RBAC roles assigned with least privilege
- [ ] Private endpoints configured (if required)

### Application Security
- [ ] Sensitive data stored in Key Vault
- [ ] Environment variables secured
- [ ] Input validation implemented
- [ ] CORS properly configured
- [ ] Authentication implemented (if required)
- [ ] Rate limiting configured
- [ ] Security headers set

### Monitoring Security
- [ ] Security Center enabled
- [ ] Log Analytics configured
- [ ] Security alerts set up
- [ ] Audit logs enabled
- [ ] Regular security assessments scheduled

### Compliance Security
- [ ] Azure policies applied
- [ ] Compliance dashboard reviewed
- [ ] Security baselines implemented
- [ ] Regular compliance scans performed

## 🐛 Security Troubleshooting

### Authentication Issues
```bash
# Check Managed Identity status
az containerapp identity show \
  --name <container-app-name> \
  --resource-group <resource-group>

# Verify role assignments
az role assignment list \
  --assignee <principal-id> \
  --all

# Test storage access
az storage file list \
  --account-name <storage-account> \
  --share-name <share-name> \
  --auth-mode login
```

### Network Access Issues
```bash
# Check network rules
az storage account show \
  --name <storage-account-name> \
  --query "networkRuleSet" \
  --output json

# Test connectivity
az containerapp exec \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --command "curl -v https://<storage-account>.file.core.windows.net/"
```

### Policy Compliance Issues
```bash
# View non-compliant resources
az policy state list \
  --filter "ComplianceState eq 'NonCompliant'" \
  --resource-group <resource-group>

# Get policy details
az policy definition show \
  --name <policy-name>

# Trigger compliance evaluation
az policy state trigger-scan \
  --resource-group <resource-group>
```

## 🔗 Related Documentation

- [Terraform Infrastructure](terraform.md)
- [Azure Deployment](azure-deployment.md)
- [Docker & Containers](docker.md)
- [Troubleshooting Guide](troubleshooting.md)

## 📚 Security Resources

- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/)
- [Azure Security Center Documentation](https://docs.microsoft.com/en-us/azure/security-center/)
- [Managed Identity Documentation](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Azure Policy Documentation](https://docs.microsoft.com/en-us/azure/governance/policy/)
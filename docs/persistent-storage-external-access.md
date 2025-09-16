# 💾 Persistent Storage with External Access

This document describes the implementation of persistent data volume with external access capabilities while maintaining strict security compliance (no shared access keys, no public IP access).

## Overview

The solution provides:
- **Persistent data volume** accessible by the Container App at `/data`
- **External access** for data upload/download from outside the Azure environment
- **Security compliance** with no shared keys or public network access
- **Azure AD authentication** for all storage operations
- **Private endpoint** connectivity for enhanced security

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Resource Group                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │ Container Apps  │◄───┤         Storage Account         │ │
│  │   Environment   │    │  ┌─────────────────────────────┐ │ │
│  │                 │    │  │      Azure Files Share     │ │ │
│  │ ┌─────────────┐ │    │  │     (Persistent Data)      │ │ │
│  │ │ FastAPI App │ │    │  │   + Private Endpoint       │ │ │
│  │ │ /data mount │ │    │  └─────────────────────────────┘ │ │
│  │ └─────────────┘ │    └──────────────────────────────────┘ │
│  └─────────────────┘                    ▲                   │
│           ▲                             │                   │
│           │                 ┌───────────┴─────────┐         │
│  ┌─────────────────┐         │   Private Endpoint │         │
│  │ Managed Identity│◄────────┤   + Private DNS    │         │
│  │ RBAC Roles:     │         │   + Network Rules  │         │
│  │ • File Data SMB │         └─────────────────────┘         │
│  │ • Blob Data     │                                         │
│  └─────────────────┘                                         │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              External Access Methods                    │ │
│  │  • Azure CLI (./external-storage-access.sh)           │ │
│  │  • Azure Storage Explorer with AAD                     │ │
│  │  • PowerShell with Azure modules                       │ │
│  │  • REST API with OAuth tokens                          │ │
│  │  • SMB Mount (from Azure VMs)                          │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Security Compliance
- ✅ **No shared access keys** - Uses Azure AD authentication exclusively
- ✅ **No public network access** - Private endpoint only connectivity
- ✅ **Infrastructure encryption** - Double encryption for data at rest
- ✅ **Network restrictions** - VNet-based access control
- ✅ **Managed Identity** - Automatic credential management
- ✅ **RBAC permissions** - Least-privilege access control

### External Access Capabilities
- 🔧 **Azure CLI integration** - Command-line file operations
- 🖥️ **Storage Explorer support** - GUI-based file management
- 📜 **PowerShell automation** - Script-based operations
- 🌐 **REST API access** - Programmatic integration
- 📁 **SMB mounting** - Direct file system access (from Azure VMs)

## Implementation Details

### 1. Infrastructure Components

#### Virtual Network and Private Endpoint
```hcl
# VNet for private connectivity
resource "azurerm_virtual_network" "main" {
  address_space = ["10.0.0.0/16"]
}

# Private endpoint for Azure Files
resource "azurerm_private_endpoint" "storage_file" {
  private_service_connection {
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names             = ["file"]
  }
}
```

#### Storage Account Configuration
```hcl
resource "azurerm_storage_account" "main" {
  shared_access_key_enabled       = false  # Security compliance
  public_network_access_enabled   = false  # Private only
  infrastructure_encryption_enabled = true # Double encryption
  
  network_rules {
    default_action = "Deny"           # Block all by default
    bypass         = ["AzureServices"] # Allow Azure services
  }
}
```

#### RBAC Role Assignments
```hcl
# Container App Managed Identity gets SMB access
resource "azurerm_role_assignment" "storage_file_smb_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
```

### 2. Container App Integration

#### Volume Configuration
```hcl
# Always-mounted persistent volume
resource "azurerm_container_app" "main" {
  template {
    container {
      volume_mounts {
        name = "data-volume"
        path = "/data"
      }
    }
    
    volume {
      name         = "data-volume"
      storage_type = "AzureFile"
      storage_name = "data-storage"
    }
  }
}
```

#### Environment Storage
```hcl
# Uses Managed Identity authentication (no access keys)
resource "azurerm_container_app_environment_storage" "data" {
  account_name = azurerm_storage_account.main.name
  share_name   = azurerm_storage_share.main.name
  access_mode  = "ReadWrite"
  # No access_key - uses Managed Identity
}
```

## External Access Methods

### 1. Azure CLI Script (Recommended)

The provided script [`external-storage-access.sh`](../azure-scripts/external-storage-access.sh) offers comprehensive file operations:

```bash
# Make executable
chmod +x external-storage-access.sh

# List files
./external-storage-access.sh list

# Upload file
./external-storage-access.sh upload ./local-file.txt remote-file.txt

# Download file
./external-storage-access.sh download remote-file.txt ./local-copy.txt

# Create directory
./external-storage-access.sh mkdir uploads

# Delete file
./external-storage-access.sh delete old-file.txt

# Get file info
./external-storage-access.sh info data-file.txt

# Test connectivity
./external-storage-access.sh test
```

**Features:**
- ✅ Azure AD authentication
- ✅ Automatic resource discovery via Terraform outputs
- ✅ Comprehensive error handling
- ✅ Colored output for better UX
- ✅ Interactive confirmations for destructive operations

### 2. Azure Storage Explorer (GUI)

1. **Download**: [Azure Storage Explorer](https://azure.microsoft.com/en-us/products/storage/storage-explorer/)
2. **Connect**: Use "Add an Azure Account" option
3. **Navigate**: Subscription → Resource Group → Storage Account → File Shares
4. **Access**: Upload, download, and manage files through GUI

**Benefits:**
- User-friendly graphical interface
- Drag-and-drop file operations
- Built-in Azure AD integration
- Cross-platform support (Windows, macOS, Linux)

### 3. PowerShell with Azure Modules

```powershell
# Install Azure PowerShell (if not already installed)
Install-Module -Name Az -Scope CurrentUser

# Connect to Azure
Connect-AzAccount

# Get storage context using Managed Identity
$resourceGroupName = "your-resource-group"
$storageAccountName = "your-storage-account"
$shareName = "your-share-name"

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$ctx = $storageAccount.Context

# List files
Get-AzStorageFile -ShareName $shareName -Context $ctx

# Upload file
Set-AzStorageFileContent -ShareName $shareName -Source "local-file.txt" -Path "remote-file.txt" -Context $ctx

# Download file
Get-AzStorageFileContent -ShareName $shareName -Path "remote-file.txt" -Destination "local-copy.txt" -Context $ctx
```

### 4. REST API Access

```bash
# Get Azure AD token
TOKEN=$(az account get-access-token --resource https://storage.azure.com/ --query accessToken -o tsv)

# List files
curl -H "Authorization: Bearer $TOKEN" \
     -H "x-ms-version: 2020-04-08" \
     "https://<storage-account>.file.core.windows.net/<share>?restype=directory&comp=list"

# Upload file
curl -X PUT \
     -H "Authorization: Bearer $TOKEN" \
     -H "x-ms-version: 2020-04-08" \
     -H "x-ms-type: file" \
     -H "x-ms-content-length: $(stat -c%s local-file.txt)" \
     --data-binary @local-file.txt \
     "https://<storage-account>.file.core.windows.net/<share>/remote-file.txt"
```

### 5. SMB Mount (from Azure VMs)

For Azure VMs in the same VNet:

```bash
# Create mount point
sudo mkdir -p /mnt/azurefiles

# Mount using Azure AD credentials
sudo mount -t cifs //<storage-account>.file.core.windows.net/<share> /mnt/azurefiles \
  -o vers=3.0,username=<managed-identity-client-id>,password="",dir_mode=0777,file_mode=0777,cache=strict,actimeo=30
```

## Deployment Instructions

### 1. Deploy Infrastructure

```bash
cd azure-scripts

# Deploy with private endpoint support
terraform plan -var="allow_shared_key_access=false" -var="allow_public_network_access=false"
terraform apply -var="allow_shared_key_access=false" -var="allow_public_network_access=false"
```

### 2. Verify Deployment

```bash
# Check deployment status
terraform output

# Test Container App
curl "$(terraform output -raw container_app_url)/health"

# Test external access
./external-storage-access.sh test
```

### 3. Upload Test Data

```bash
# Create test file
echo "Hello from external access!" > test-data.txt

# Upload via script
./external-storage-access.sh upload test-data.txt

# Verify in Container App
curl "$(terraform output -raw container_app_url)/list-files"
```

## Security Considerations

### Authentication Flow
1. **External User** authenticates with Azure AD
2. **Azure AD** issues access token with appropriate scopes
3. **Access Token** is used to authenticate with Azure Files
4. **Azure RBAC** validates permissions for the operation
5. **Private Endpoint** provides secure network connectivity

### Network Security
- All traffic flows through private endpoints
- No public internet exposure of storage account
- VNet-based network access controls
- NSG rules for additional security

### Identity and Access Management
- Managed Identity for Container App authentication
- RBAC roles with least-privilege access
- Azure AD integration for external users
- No stored credentials or access keys

## Monitoring and Troubleshooting

### Monitoring
```bash
# Check storage account metrics
az monitor metrics list \
  --resource "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<sa>" \
  --metric "Transactions,Availability,SuccessE2ELatency"

# Check Container App logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow
```

### Common Issues

#### 1. Authentication Failures
```bash
# Check Azure login status
az account show

# Re-authenticate if needed
az login --tenant <tenant-id>

# Verify RBAC permissions
az role assignment list --assignee <principal-id>
```

#### 2. Network Connectivity
```bash
# Test private endpoint resolution
nslookup <storage-account>.file.core.windows.net

# Check network rules
az storage account show \
  --name <storage-account> \
  --query "networkRuleSet" \
  --output json
```

#### 3. Permission Issues
```bash
# List effective permissions
az role assignment list \
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<sa>"

# Test file operations
az storage file list \
  --account-name <storage-account> \
  --share-name <share> \
  --auth-mode login
```

## Cost Optimization

### Storage Costs
- **Hot tier**: Optimized for frequent access (~€0.0184/GB/month)
- **Cool tier**: Lower storage costs for infrequent access (~€0.0115/GB/month)
- **Transaction costs**: ~€0.0043 per 10,000 transactions

### Network Costs
- **Private endpoint**: ~€0.0072/hour (~€5.30/month)
- **VNet peering**: If cross-region access needed
- **Data transfer**: Usually free within same region

### Optimization Tips
1. Use appropriate access tiers based on usage patterns
2. Implement lifecycle policies for old data
3. Monitor transaction patterns and optimize access methods
4. Consider data compression for large files

## Related Documentation

- [Security & Configuration](security.md) - Detailed security implementation
- [Azure Deployment](azure-deployment.md) - Infrastructure deployment guide
- [API Documentation](api.md) - Container App API endpoints
- [Terraform Infrastructure](terraform.md) - Infrastructure as code details
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## Additional Resources

- [Azure Files Documentation](https://docs.microsoft.com/en-us/azure/storage/files/)
- [Private Endpoints Documentation](https://docs.microsoft.com/en-us/azure/private-link/)
- [Managed Identity Documentation](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Azure Container Apps Storage](https://docs.microsoft.com/en-us/azure/container-apps/storage-mounts)
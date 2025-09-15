# FastAPI Azure Container Apps with Persistent Storage

A complete solution for deploying a FastAPI application to Azure Container Apps using Docker with persistent Azure Storage integration.

## 🏗️ Architecture Overview

- **Application**: FastAPI REST API with file operations
- **Containerization**: Docker with Azure Container Registry (ACR)
- **Hosting**: Azure Container Apps (serverless containers)
- **Storage**: Azure Storage File Share for persistence
- **Container Registry**: Azure Container Registry for private Docker images
- **Automation**: Terraform for infrastructure as code and Azure CLI scripts

## 📁 Project Structure

```
├── app/
│   ├── main.py              # FastAPI application
│   ├── dwh.py               # Data warehouse module with DuckDB integration
│   ├── config.toml          # Configuration file for database and analytics
│   └── requirements.txt     # Python dependencies
├── azure-scripts/
│   ├── provider.tf                    # Terraform provider configuration
│   ├── variables.tf                   # Terraform variables definition
│   ├── main.tf                        # Main infrastructure configuration
│   ├── outputs.tf                     # Terraform outputs
│   ├── terraform-deploy.sh            # Terraform deployment script
│   ├── terraform-cleanup.sh           # Resource cleanup script
│   ├── docker-build-push.sh           # Docker build and push to ACR script
│   ├── full-deploy.sh                 # Complete end-to-end deployment script
│   └── CONTAINER-REGISTRY-GUIDE.md    # Detailed Container Registry guide
├── docker-compose.yml       # Container orchestration
├── Dockerfile              # Container definition
├── test-api.sh             # Comprehensive API testing script
├── test-aip.rest           # REST client test file
└── README.md               # This file
```

## 🚀 Features

### FastAPI Application
- **GET /**: Health check endpoint
- **GET /health**: Detailed health check with volume status
- **POST /write-file**: Write content to persistent storage
- **GET /list-files**: List all files in persistent storage
- **GET /read-file/{filename}**: Read file content from storage
- **POST /init-dwh**: Initialize the data warehouse with DuckDB and DuckLake
- **GET /query**: Execute analytics queries on e-commerce data

### Data Warehouse Features
- **DuckDB Integration**: High-performance analytical database
- **DuckLake Extension**: Data lakehouse functionality
- **TOML Configuration**: Flexible configuration management
- **Analytics Queries**: Pre-built e-commerce analytics with customer demographics
- **Parquet Support**: Direct querying of Parquet files

### Infrastructure
- Resource Group with all components
- Azure Container Registry (ACR) for private Docker images
- Azure Storage Account with File Share
- Container App Environment
- Container App with auto-scaling capabilities
- Persistent volume mounting with Azure Files
- Managed Identity for secure ACR access

## 📋 Prerequisites

1. **Terraform** (>= 1.0) installed
   ```bash
   # Install Terraform
   sudo snap install terraform
   
   # Or using other methods: https://www.terraform.io/downloads.html
   terraform --version
   ```

2. **Azure CLI** installed and configured
   ```bash
   # Install Azure CLI (if not already installed)
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Login to Azure
   az login
   ```

3. **Docker** (for local testing)
   ```bash
   # Verify Docker is installed
   docker --version
   docker-compose --version
   ```

3. **Git** (to clone the repository)

## 🔧 Quick Start

### Option 1: Automated Deployment (Recommended)
```bash
git clone <repository-url>
cd azure-webapp-container-demo
chmod +x azure-scripts/*.sh

# Complete deployment with Container Registry
cd azure-scripts
./full-deploy.sh latest
```

This will automatically:
- Deploy Azure infrastructure (ACR, Container Apps, Storage)
- Build and push Docker image to Azure Container Registry
- Configure Container App to use the private registry
- Update the application with the new image

### Option 2: Manual Step-by-Step Deployment

#### Step 1: Clone and Setup
```bash
git clone <repository-url>
cd azure-webapp-container-demo
chmod +x azure-scripts/*.sh
```

#### Step 2: Deploy Infrastructure with Terraform
```bash
cd azure-scripts
./terraform-deploy.sh
```

This script will:
- Initialize Terraform and validate configuration
- Create a resource group
- Set up Azure Container Registry (ACR)
- Set up Azure Storage with File Share
- Create Container App Environment and Container App
- Configure ACR integration with Managed Identity
- Configure persistent storage mounting
- Provide deployment information and next steps

#### Step 3: Build and Push Docker Image
```bash
# Build and push to Azure Container Registry
./docker-build-push.sh latest

# Or with custom tag
./docker-build-push.sh v1.0.0
```

## 🐳 Azure Container Registry (ACR) Integration

### Overview
The application now uses Azure Container Registry for secure, private Docker image storage instead of public registries like Docker Hub.

### Benefits
- **Security**: Private registry accessible only by authorized Azure resources
- **Performance**: Images are stored in the same Azure region for faster pulls
- **Integration**: Seamless integration with Azure App Service using Managed Identity
- **Cost-effective**: No data transfer costs between ACR and App Service

### Container Registry Features
- **Private Registry**: All images stored securely in your Azure subscription
- **Managed Identity Authentication**: No stored credentials or access keys
- **Role-based Access Control**: Minimal permissions with AcrPull role
- **Automated Build & Push**: Scripts for easy image management

### Quick Commands
```bash
# Build and push new image version
cd azure-scripts
./docker-build-push.sh v1.2.0

# Complete deployment with new image
./full-deploy.sh v1.2.0

# List images in registry
az acr repository show-tags --name $(terraform output -raw container_registry_name) --repository fastapi-app

# View registry details
terraform output container_registry_login_server
```

### Image Tagging Strategy
- `latest` - Most recent version (default)
- `v1.0.0` - Semantic versioning for releases
- `feature-xyz` - Development branches
- `commit-abc123` - Specific commit builds

For detailed information, see [`CONTAINER-REGISTRY-GUIDE.md`](azure-scripts/CONTAINER-REGISTRY-GUIDE.md).

### Step 4: Test the Application
The setup script will provide the Container App URL. Test the endpoints:

```bash
# Health check
curl https://your-container-app.azurecontainerapps.io/health

# Write a file
curl -X POST "https://your-container-app.azurecontainerapps.io/write-file" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello World from Azure Container Apps!","filename":"test.txt"}'

# List files
curl https://your-container-app.azurecontainerapps.io/list-files

# Read file
curl https://your-container-app.azurecontainerapps.io/read-file/test.txt

# Initialize data warehouse
curl -X POST https://your-container-app.azurecontainerapps.io/init-dwh

# Execute analytics query
curl https://your-container-app.azurecontainerapps.io/query
```

### Automated Testing
Use the provided test script for comprehensive API testing:

```bash
# Test locally
./test-api.sh

# Test deployed application
./test-api.sh https://your-container-app.azurecontainerapps.io

# See all available options
./test-api.sh --help
```

## 🔄 Redeployment

### Complete Redeployment (Infrastructure + Application)
For full updates including infrastructure changes:

```bash
cd azure-scripts
./full-deploy.sh [tag]
```

### Application Updates Only
To update just the application after code changes:

```bash
# Build and push new image
./docker-build-push.sh v1.1.0

# Update Container App to use new image
az containerapp update --name $(terraform output -raw container_app_name) --resource-group $(terraform output -raw resource_group_name) --image $(terraform output -raw container_registry_login_server)/fastapi-app:v1.1.0
```

### Infrastructure Updates Only
To update infrastructure without rebuilding the image:

```bash
cd azure-scripts
./terraform-deploy.sh
```

## 🧪 Local Testing

Test the application locally before deploying:

```bash
# Build and run with Docker Compose
docker-compose up --build

# Test locally
curl -X POST "http://localhost:8000/write-file" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello Local World!","filename":"local-test.txt"}'

# Test data warehouse functionality
curl -X POST "http://localhost:8000/init-dwh"
curl "http://localhost:8000/query"

# Or use the test script
./test-api.sh
```

## 📊 Monitoring and Logs

### View Application Logs
```bash
# Real-time logs
az containerapp logs show --name <container-app-name> --resource-group <resource-group> --follow

# Show recent logs
az containerapp logs show --name <container-app-name> --resource-group <resource-group>
```

### Application Insights (Optional)
To enable detailed monitoring, add Application Insights:

```bash
az monitor app-insights component create \
  --app <container-app-name>-insights \
  --location "West Europe" \
  --resource-group <resource-group>
```

## 🗃️ Data Warehouse Configuration

### Configuration File (config.toml)
The application uses TOML configuration for flexible data warehouse setup:

```toml
[database]
ducklake_path = "/data/ecommerce_analytics.ducklake"
data_path = "/data/lakehouse/"

[parquet_files]
base_path = "/data/archive/parquet/"

[parquet_files.files]
customers = "customers.parquet"
products = "products.parquet"
orders = "orders.parquet"
order_items = "order_items.parquet"
product_reviews = "product_reviews.parquet"

[tables]
customers = "customers"
products = "products"
orders = "orders"
order_items = "order_items"
product_reviews = "product_reviews"

[analytics]
top_countries_limit = 10
```

### Data Warehouse Features
- **DuckDB**: Fast analytical processing
- **DuckLake**: Data lakehouse with ACID transactions
- **Parquet Integration**: Direct querying of Parquet files
- **E-commerce Analytics**: Pre-built queries for sales analysis
- **Customer Demographics**: Gender-based analytics and insights

## 🔧 Configuration

### Terraform Variables
You can customize the deployment by modifying variables in `variables.tf`:

#### Infrastructure Variables
- `resource_group_name`: Name of the resource group (default: "jkl-open-data-platform")
- `location`: Azure region (default: "West Europe")
- `container_app_environment_name`: Name of Container App Environment
- `container_app_name_prefix`: Prefix for Container App name
- `storage_account_name_prefix`: Prefix for Storage Account name
- `container_app_cpu`: CPU allocation (default: 0.5)
- `container_app_memory`: Memory allocation (default: "1Gi")
- `container_app_min_replicas`: Minimum replicas (default: 1)
- `container_app_max_replicas`: Maximum replicas (default: 5)

#### Security Variables
- `enable_infrastructure_encryption`: Enable double encryption for storage account (default: `true`)
- `allow_shared_key_access`: Allow shared key access to storage account (default: `false` - for security policy compliance)
- `allow_public_network_access`: Allow public network access to storage account (default: `false` - for security compliance)
- `enable_network_restriction`: Enable network access restrictions (default: `true` - for security compliance)

**Security Policy Compliance**:
- **Shared Key Access**: Set to `false` by default to comply with "Storage accounts should prevent shared key access" policy
- **Public Network Access**: Disabled by default (`allow_public_network_access = false`) to comply with security policies
- **Network Restrictions**: Enabled by default with Azure Services bypass to ensure secure access
- **Infrastructure Encryption**: Double encryption enabled for data at rest

**Important Note on Persistent Storage**:
When `allow_shared_key_access = false` (default for security compliance):
- Azure Files persistent storage will NOT be available to the Container App
- The application will run without persistent storage mounted at `/data`
- All file operations will use ephemeral storage (lost on container restart)
- To enable persistent storage, set `allow_shared_key_access = true` in variables

**Alternative for Persistent Storage**:
For production environments requiring both security compliance AND persistent storage, consider:
- Using Azure Database services instead of file-based storage
- Implementing external storage solutions with proper authentication
- Using Azure Key Vault for sensitive data instead of file storage

### Environment Variables
The application supports these environment variables:
- `PYTHONPATH=/app`
- `PYTHONUNBUFFERED=1`

### Storage Configuration
- **Mount Path**: `/data`
- **Azure File Share**: Automatically configured
- **Storage Type**: Azure Files (SMB)

### Scaling
Container Apps automatically scale based on demand. To configure scaling:

```bash
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --min-replicas 0 \
  --max-replicas 10
```

## 🏗️ Terraform Infrastructure Details

### Resources Created
- **Resource Group**: Contains all Azure resources
- **Azure Container Registry (ACR)**: Private registry for Docker images
  - SKU: Basic (configurable)
  - Admin user enabled for authentication
  - System-assigned Managed Identity
- **Storage Account**: With randomly generated suffix for uniqueness and security policies applied
  - Infrastructure encryption enabled (double encryption)
  - Shared key access disabled (uses Managed Identity)
  - Network access restricted (Deny by default, allow Azure services)
- **Azure File Share**: For persistent data storage
- **Container App Environment**: Managed environment for Container Apps
- **Container App**: Serverless containers with auto-scaling and ACR integration
- **Storage Mount**: Automatically configured for `/data` path using Azure Files
- **RBAC Role Assignments**:
  - `Storage File Data SMB Share Contributor` - for file share access
  - `AcrPull` - for Container App to pull images from Container Registry

### Terraform State Management
- State is stored locally by default
- For production environments, consider using Azure Storage backend:
  ```hcl
  terraform {
    backend "azurerm" {
      resource_group_name  = "terraform-state-rg"
      storage_account_name = "terraformstatestore"
      container_name       = "tfstate"
      key                 = "fastapi-webapp.terraform.tfstate"
    }
  }
  ```

### Terraform Commands
```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy resources
terraform destroy
```

## 🔒 Security Considerations

### Azure Security Policies Implementation

This infrastructure implements Azure security best practices with two key policies:

#### 1. **Storage Accounts Prevent Shared Key Access**
- **Policy**: `shared_access_key_enabled = false` (enforced by default)
- **Configuration**: Configurable via `allow_shared_key_access` variable (defaults to `false`)
- **Security Benefit**: Eliminates the risk of compromised access keys by disabling shared key authentication
- **Authentication Method**: Uses **Managed Identity** with RBAC role assignments exclusively

**Implementation**: Storage mount is configured post-deployment via Azure CLI using Managed Identity, avoiding the need for access keys entirely.

#### 2. **Storage Accounts with Infrastructure Encryption**
- **Policy**: `infrastructure_encryption_enabled = true`
- **Configuration**: Configurable via `enable_infrastructure_encryption` variable (defaults to `true`)
- **Security Benefit**: Provides **double encryption** - encryption at service level AND infrastructure level
- **Compliance**: Meets enterprise security requirements for data protection

#### 3. **App Service Apps Should Only Be Accessible Over HTTPS**
- **Policy**: `https_only = true`
- **Configuration**: Configurable via `https_only` variable (defaults to `true`)
- **Security Benefit**: Forces all HTTP traffic to be redirected to HTTPS, ensuring encrypted communication
- **Compliance**: Prevents data transmission over unencrypted connections

### Managed Identity Configuration

The Web App uses **System-Assigned Managed Identity** for secure storage access:

```hcl
# Web App with Managed Identity
identity {
  type = "SystemAssigned"
}

# RBAC Role Assignments
resource "azurerm_role_assignment" "storage_file_data_smb_share_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
```

### Security Features Summary
1. **Managed Identity Authentication**: No stored credentials or access keys
2. **Infrastructure Encryption**: Double encryption for data at rest
3. **Network Isolation**: Storage with restricted network access (`default_action = "Deny"`)
4. **HTTPS Enforcement**: `https_only = true` forces all traffic to HTTPS
5. **Container Security**: Uses official Python slim image
6. **Azure Network**: App runs in Azure's secure network environment
7. **RBAC**: Principle of least privilege with specific role assignments

### Security Variables Configuration

You can customize security settings in `variables.tf`:

```hcl
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
```

**Automated Two-Phase Security Deployment**:
1. **Initial Deployment**: Infrastructure created with temporary key access (Terraform compatibility)
2. **Automatic Hardening**: Script automatically disables shared keys post-deployment
3. **Storage Mount**: Configured using Managed Identity authentication only
4. **Final State**: Full compliance with all Azure security policies

**Security Timeline**:
- ✅ **Infrastructure Encryption**: Enabled from deployment start
- ✅ **HTTPS Enforcement**: Enabled from deployment start
- ✅ **Shared Key Disable**: Applied automatically after initial resource creation
- ✅ **Managed Identity**: Active throughout entire process

## 💰 Cost Estimation

Approximate monthly costs (West Europe):
- **Container Apps**: Pay-per-use (€0.000024/vCPU-second, €0.000003/GiB-second)
- **Azure Container Registry (Basic)**: ~€4.50/month + storage
- **Storage Account (LRS)**: ~€0.05/GB/month
- **Data Transfer**: Minimal for API usage (no charges between ACR and Container Apps in same region)

**Total estimated cost**: ~€5-15/month depending on usage (much lower with Container Apps auto-scaling)

## 🧹 Cleanup

To remove all resources created by Terraform:

```bash
cd azure-scripts
./terraform-cleanup.sh
```

**Warning**: This will delete all data permanently! The script requires typing "destroy" to confirm.

## 🐛 Troubleshooting

### Common Issues

1. **Container fails to start**
   ```bash
   # Check container logs
   az containerapp logs show --name <container-app-name> --resource-group <resource-group>
   ```

2. **Image pull from ACR fails**
   ```bash
   # Verify ACR access permissions
   az acr check-health --name $(terraform output -raw container_registry_name)
   
   # Check role assignments
   az role assignment list --assignee $(az containerapp identity show --name <container-app-name> --resource-group <resource-group> --query principalId -o tsv)
   
   # Update Container App to trigger new deployment
   az containerapp update --name <container-app-name> --resource-group <resource-group>
   ```

3. **Storage not accessible**
   ```bash
   # Verify Container App Environment storage
   az containerapp env storage list --name <container-app-environment> --resource-group <resource-group>
   ```

4. **Application not responding**
   ```bash
   # Restart the Container App
   az containerapp revision restart --name <container-app-name> --resource-group <resource-group>
   ```

5. **Docker build fails locally**
   ```bash
   # Test build locally first
   docker build -t test-image .
   docker run -p 8000:8000 test-image
   
   # Check build logs
   ./docker-build-push.sh 2>&1 | tee build.log
   ```

### Container Registry Troubleshooting
- **Access Denied**: Ensure Managed Identity has AcrPull role
- **Image Not Found**: Verify image was pushed successfully with `az acr repository list`
- **Authentication Issues**: Check ACR admin user is enabled if using basic auth
- **Network Issues**: Verify ACR and Container Apps are in same region

For detailed troubleshooting, see [`CONTAINER-REGISTRY-GUIDE.md`](azure-scripts/CONTAINER-REGISTRY-GUIDE.md).

### Health Check Endpoints
- **Basic**: `GET /` - Returns simple status
- **Detailed**: `GET /health` - Includes storage accessibility

### Data Warehouse Endpoints
- **Initialize**: `POST /init-dwh` - Set up DuckDB and create tables
- **Analytics**: `GET /query` - Execute pre-built analytics queries

### Testing Tools
- **Bash Script**: [`test-api.sh`](test-api.sh) - Comprehensive endpoint testing
- **REST Client**: [`test-aip.rest`](test-aip.rest) - Visual Studio Code REST client tests

## 📚 API Documentation

Once deployed, access the interactive API documentation:
- **Swagger UI**: `https://your-container-app.azurecontainerapps.io/docs`
- **ReDoc**: `https://your-container-app.azurecontainerapps.io/redoc`

### Sample API Workflow
1. **Health Check**: `GET /health` - Verify application and storage status
2. **Initialize DWH**: `POST /init-dwh` - Set up data warehouse tables
3. **Run Analytics**: `GET /query` - Execute e-commerce analytics
4. **File Operations**: Use `/write-file`, `/list-files`, `/read-file` for data management

## 🔄 CI/CD Integration

For automated deployments, integrate with GitHub Actions:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure with Terraform
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: "1.0"
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Deploy Infrastructure
        run: |
          cd azure-scripts
          ./terraform-deploy.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with Docker Compose
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Azure Container Apps documentation
3. Open an issue in this repository

---

**Note**: This solution uses Azure Container Apps, which provides serverless containers with automatic scaling. Container Apps is generally available and included in most Azure subscriptions.
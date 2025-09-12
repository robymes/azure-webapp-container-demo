# FastAPI Azure Web App with Docker Compose and Persistent Storage

A complete solution for deploying a FastAPI application to Azure Web App Service for Containers using Docker Compose with persistent Azure Storage integration.

## 🏗️ Architecture Overview

- **Application**: FastAPI REST API with file operations
- **Containerization**: Docker with Docker Compose
- **Hosting**: Azure Web App Service for Containers (Linux)
- **Storage**: Azure Storage File Share for persistence
- **Automation**: Terraform for infrastructure as code and Azure CLI scripts

## 📁 Project Structure

```
├── app/
│   ├── main.py              # FastAPI application
│   ├── dwh.py               # Data warehouse module with DuckDB integration
│   ├── config.toml          # Configuration file for database and analytics
│   └── requirements.txt     # Python dependencies
├── azure-scripts/
│   ├── provider.tf             # Terraform provider configuration
│   ├── variables.tf            # Terraform variables definition
│   ├── main.tf                 # Main infrastructure configuration
│   ├── outputs.tf              # Terraform outputs
│   ├── terraform-deploy.sh     # Terraform deployment script
│   └── terraform-cleanup.sh    # Resource cleanup script
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
- Azure Storage Account with File Share
- App Service Plan (Linux, B1 SKU)
- Web App for Containers with Docker Compose support
- Persistent volume mounting with Azure Files

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

### Step 1: Clone and Setup
```bash
git clone <repository-url>
cd azure-webapp-container-demo
chmod +x azure-scripts/*.sh
```

### Step 2: Deploy Infrastructure with Terraform
```bash
cd azure-scripts
./terraform-deploy.sh
```

This script will:
- Initialize Terraform and validate configuration
- Create a resource group
- Set up Azure Storage with File Share
- Create App Service Plan and Web App
- Configure persistent storage mounting
- Provide deployment information and next steps

### Step 3: Test the Application
The setup script will provide the Web App URL. Test the endpoints:

```bash
# Health check
curl https://your-webapp-url.azurewebsites.net/health

# Write a file
curl -X POST "https://your-webapp-url.azurewebsites.net/write-file" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello World from Azure!","filename":"test.txt"}'

# List files
curl https://your-webapp-url.azurewebsites.net/list-files

# Read file
curl https://your-webapp-url.azurewebsites.net/read-file/test.txt

# Initialize data warehouse
curl -X POST https://your-webapp-url.azurewebsites.net/init-dwh

# Execute analytics query
curl https://your-webapp-url.azurewebsites.net/query
```

### Automated Testing
Use the provided test script for comprehensive API testing:

```bash
# Test locally
./test-api.sh

# Test deployed application
./test-api.sh https://your-webapp-url.azurewebsites.net

# See all available options
./test-api.sh --help
```

## 🔄 Redeployment

### Infrastructure Updates
To update infrastructure with Terraform:

```bash
cd azure-scripts
./terraform-deploy.sh
```

### Docker Compose Updates
After infrastructure is deployed, configure Docker Compose manually:

```bash
# Get web app name and resource group from Terraform outputs
terraform output

# Configure Docker Compose
az webapp config container set \
  --name "<web-app-name>" \
  --resource-group "rg-fastapi-webapp" \
  --multicontainer-config-type compose \
  --multicontainer-config-file docker-compose.yml
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
az webapp log tail --name <web-app-name> --resource-group rg-fastapi-webapp

# Download log files
az webapp log download --name <web-app-name> --resource-group rg-fastapi-webapp
```

### Application Insights (Optional)
To enable detailed monitoring, add Application Insights:

```bash
az monitor app-insights component create \
  --app <web-app-name>-insights \
  --location "West Europe" \
  --resource-group rg-fastapi-webapp
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
- `resource_group_name`: Name of the resource group (default: "rg-fastapi-webapp")
- `location`: Azure region (default: "West Europe")
- `app_service_plan_sku`: SKU for App Service Plan (default: "B1")
- `web_app_name_prefix`: Prefix for Web App name
- `storage_account_name_prefix`: Prefix for Storage Account name

#### Security Variables
- `enable_infrastructure_encryption`: Enable double encryption for storage account (default: `true`)
- `allow_shared_key_access`: Allow shared key access to storage account (default: `false`)
- `https_only`: Force HTTPS only access for App Service (default: `true`)

**Security Recommendation**: Keep the default security values for production environments:
- `enable_infrastructure_encryption = true` (storage double encryption)
- `allow_shared_key_access = false` (no shared keys)
- `https_only = true` (HTTPS enforced)

### Environment Variables
The application supports these environment variables:
- `PYTHONPATH=/app`
- `PYTHONUNBUFFERED=1`

### Storage Configuration
- **Mount Path**: `/data`
- **Azure File Share**: Automatically configured
- **Storage Type**: Azure Files (SMB)

### Scaling
To scale the App Service Plan:

```bash
az appservice plan update \
  --name asp-fastapi-webapp \
  --resource-group rg-fastapi-webapp \
  --sku P1V2
```

## 🏗️ Terraform Infrastructure Details

### Resources Created
- **Resource Group**: Contains all Azure resources
- **Storage Account**: With randomly generated suffix for uniqueness and security policies applied
  - Infrastructure encryption enabled (double encryption)
  - Shared key access disabled (uses Managed Identity)
  - Network access restricted (Deny by default, allow Azure services)
- **Azure File Share**: For persistent data storage
- **App Service Plan**: Linux-based plan with configurable SKU
- **Linux Web App**: Container-ready with Docker support and System-Assigned Managed Identity
- **Storage Mount**: Automatically configured for `/data` path using Managed Identity
- **RBAC Role Assignments**:
  - `Storage File Data SMB Share Contributor` - for file share access
  - `Storage Account Contributor` - for storage account operations

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
- **App Service Plan B1**: ~€12.41/month
- **Storage Account (LRS)**: ~€0.05/GB/month
- **Data Transfer**: Minimal for API usage

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
   az webapp log tail --name <web-app-name> --resource-group rg-fastapi-webapp
   ```

2. **Storage not accessible**
   ```bash
   # Verify storage mount
   az webapp config storage-account list \
     --name <web-app-name> \
     --resource-group rg-fastapi-webapp
   ```

3. **Application not responding**
   ```bash
   # Restart the web app
   az webapp restart --name <web-app-name> --resource-group rg-fastapi-webapp
   ```

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
- **Swagger UI**: `https://your-webapp-url.azurewebsites.net/docs`
- **ReDoc**: `https://your-webapp-url.azurewebsites.net/redoc`

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
2. Review Azure Web App documentation
3. Open an issue in this repository

---

**Note**: This solution uses Azure Web App Service for Containers with Docker Compose preview feature. Ensure your Azure subscription supports this feature.
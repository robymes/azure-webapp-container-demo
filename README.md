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
└── README.md               # This file
```

## 🚀 Features

### FastAPI Application
- **GET /**: Health check endpoint
- **GET /health**: Detailed health check with volume status
- **POST /write-file**: Write content to persistent storage
- **GET /list-files**: List all files in persistent storage
- **GET /read-file/{filename}**: Read file content from storage

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

## 🔧 Configuration

### Terraform Variables
You can customize the deployment by modifying variables in `variables.tf`:
- `resource_group_name`: Name of the resource group (default: "rg-fastapi-webapp")
- `location`: Azure region (default: "West Europe")
- `app_service_plan_sku`: SKU for App Service Plan (default: "B1")
- `web_app_name_prefix`: Prefix for Web App name
- `storage_account_name_prefix`: Prefix for Storage Account name

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
- **Storage Account**: With randomly generated suffix for uniqueness
- **Azure File Share**: For persistent data storage
- **App Service Plan**: Linux-based plan with configurable SKU
- **Linux Web App**: Container-ready with Docker support
- **Storage Mount**: Automatically configured for `/data` path

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

1. **Storage Access**: Uses Azure Storage Account keys (consider using Managed Identity)
2. **HTTPS**: Automatically enabled for `*.azurewebsites.net` domains
3. **Container Security**: Uses official Python slim image
4. **Network**: App runs in Azure's secure network environment

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

## 📚 API Documentation

Once deployed, access the interactive API documentation:
- **Swagger UI**: `https://your-webapp-url.azurewebsites.net/docs`
- **ReDoc**: `https://your-webapp-url.azurewebsites.net/redoc`

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
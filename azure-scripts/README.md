# Azure Deployment Scripts

This folder contains the simplified and reliable Azure deployment configuration for the FastAPI Container Apps solution with persistent storage and external access.

## 📁 File Structure

### Core Terraform Files
- **[`main.tf`](main.tf)** - Main infrastructure configuration (simplified approach)
- **[`variables.tf`](variables.tf)** - Terraform variable definitions
- **[`outputs.tf`](outputs.tf)** - Terraform outputs for deployment info
- **[`provider.tf`](provider.tf)** - Azure provider configuration

### Deployment Scripts
- **[`full-deploy.sh`](full-deploy.sh)** - Complete deployment script (recommended)
- **[`docker-build-push.sh`](docker-build-push.sh)** - Build and push Docker image

### External Storage Access
- **[`external-storage-access.sh`](external-storage-access.sh)** - External storage access script

### Utility Scripts
- **[`terraform-cleanup.sh`](terraform-cleanup.sh)** - Terraform cleanup

### Documentation
- **[`README.md`](README.md)** - This comprehensive guide
- **[`DEPLOYMENT-SUMMARY.md`](DEPLOYMENT-SUMMARY.md)** - Refactoring summary

## 🚀 Quick Deployment

### Option 1: Complete Deployment (Recommended)
```bash
cd azure-scripts
./full-deploy.sh latest
```

### Option 2: Manual Terraform Deployment
```bash
cd azure-scripts

# 1. Deploy infrastructure
terraform init
terraform apply

# 2. Build and push Docker image
./docker-build-push.sh latest

# 3. Update container app manually
az containerapp update \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --image "$(terraform output -raw container_registry_login_server)/fastapi-app:latest" \
  --target-port 8000
```

## 📋 Prerequisites

- ✅ **Azure CLI** installed and logged in (`az login`)
- ✅ **Terraform** installed (>= 1.0)
- ✅ **Docker** installed and running

## 🔧 Key Features

### Infrastructure
- **Azure Container Apps** - Serverless container hosting
- **Azure Container Registry** - Private Docker registry
- **Azure Storage Account** - Persistent file storage
- **Azure Files** - SMB-based persistent storage with external access
- **Managed Identity** - Secure authentication without stored credentials

### External Storage Access
After deployment, you can access the persistent storage externally:

```bash
# List files
./external-storage-access.sh list

# Upload files
./external-storage-access.sh upload local-file.txt

# Download files
./external-storage-access.sh download remote-file.txt

# Test connectivity
./external-storage-access.sh test
```

## 🔒 Security Features

- **Managed Identity authentication** for Azure services
- **HTTPS-only access** for Container Apps
- **Infrastructure encryption** for storage
- **RBAC permissions** with least-privilege access
- **Private container registry** with admin access for deployment

## 📊 Monitoring

Check deployment outputs:
```bash
terraform output
```

View Container App logs:
```bash
az containerapp logs show \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --follow
```

## 🧹 Cleanup

Remove all deployed resources:
```bash
./terraform-cleanup.sh
```

## 📚 Additional Resources

- [Main Project Documentation](../docs/)
- [API Documentation](../docs/api.md)
- [Persistent Storage Guide](../docs/persistent-storage-external-access.md)
- [Troubleshooting Guide](../docs/troubleshooting.md)

## 💡 Tips

1. **First deployment**: Use `./full-deploy.sh latest` for complete setup
2. **Updates**: Use `./docker-build-push.sh <tag>` and then manually update the container app
3. **External access**: Always test with `./external-storage-access.sh test` after deployment
4. **Debugging**: Check Terraform outputs with `terraform output` for all resource details
5. **Cleanup**: Use `./terraform-cleanup.sh` to remove all resources when done
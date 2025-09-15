# 🐳 Docker & Container Documentation

This document covers Docker containerization, Azure Container Registry integration, and container management for the FastAPI application.

## Overview

The application uses Docker for containerization with Azure Container Registry (ACR) for private image storage. The setup provides secure, scalable container deployment on Azure Container Apps.

## 🏗️ Container Architecture

### Base Image
- **Base**: `python:3.11-slim`
- **Size**: Optimized for production use
- **Security**: Regular security updates from official Python images
- **Performance**: Minimal footprint with required dependencies only

### Container Structure
```
/app/                    # Application directory
├── main.py             # FastAPI application
├── dwh.py              # Data warehouse module
├── config.toml         # Configuration file
└── requirements.txt    # Python dependencies

/data/                  # Persistent storage mount
├── ecommerce_analytics.ducklake
├── lakehouse/
└── archive/parquet/
```

## 📄 Dockerfile

### Complete Dockerfile
Location: [`Dockerfile`](../Dockerfile)

```dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements first for better layer caching
COPY app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ .

# Create data directory for persistent storage
RUN mkdir -p /data

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Build Optimizations
- **Layer Caching**: Requirements copied before application code
- **No Cache**: Pip install without cache to reduce image size
- **Multi-stage**: Can be enhanced with multi-stage builds for smaller images
- **Health Check**: Built-in container health monitoring

## 🚀 Local Development

### Docker Compose Setup
Location: [`docker-compose.yml`](../docker-compose.yml)

```yaml
version: '3.8'

services:
  fastapi-app:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/data
    environment:
      - PYTHONPATH=/app
      - PYTHONUNBUFFERED=1
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
```

### Local Commands

#### Build and Run
```bash
# Build and start services
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

#### Direct Docker Commands
```bash
# Build image
docker build -t fastapi-azure-app .

# Run container
docker run -p 8000:8000 \
  -v $(pwd)/data:/data \
  -e PYTHONPATH=/app \
  -e PYTHONUNBUFFERED=1 \
  fastapi-azure-app

# Run with shell access
docker run -it --entrypoint /bin/bash fastapi-azure-app
```

## ☁️ Azure Container Registry (ACR)

### Overview
Azure Container Registry provides secure, private Docker image storage with integration to Azure Container Apps.

### Benefits
- **Security**: Private registry with access control
- **Performance**: Same region deployment for faster pulls
- **Integration**: Seamless Azure services integration
- **Cost-effective**: No data transfer costs within Azure

### Registry Configuration
- **SKU**: Basic (configurable to Standard/Premium)
- **Authentication**: Managed Identity (recommended) or Admin user
- **Geo-replication**: Available in Standard/Premium SKUs
- **Webhooks**: Integration with CI/CD pipelines

## 🔧 Build and Push Process

### Automated Build Script
Location: [`azure-scripts/docker-build-push.sh`](../azure-scripts/docker-build-push.sh)

```bash
#!/bin/bash
TAG=${1:-latest}

# Get ACR details from Terraform
ACR_NAME=$(terraform output -raw container_registry_name)
ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server)

echo "Building and pushing Docker image with tag: $TAG"

# Login to ACR
az acr login --name $ACR_NAME

# Build image
docker build -t $ACR_LOGIN_SERVER/fastapi-app:$TAG .

# Push to ACR
docker push $ACR_LOGIN_SERVER/fastapi-app:$TAG

echo "Image pushed successfully: $ACR_LOGIN_SERVER/fastapi-app:$TAG"
```

### Usage Examples
```bash
# Build and push latest
cd azure-scripts
./docker-build-push.sh latest

# Build and push with version tag
./docker-build-push.sh v1.2.0

# Build and push development version
./docker-build-push.sh dev-feature-branch
```

### Manual Build and Push
```bash
# Get ACR details
ACR_NAME=$(terraform output -raw container_registry_name)
ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server)

# Login to ACR
az acr login --name $ACR_NAME

# Build image
docker build -t $ACR_LOGIN_SERVER/fastapi-app:latest .

# Push image
docker push $ACR_LOGIN_SERVER/fastapi-app:latest
```

## 🏷️ Image Tagging Strategy

### Recommended Tags
- `latest` - Most recent stable version
- `v1.0.0` - Semantic versioning for releases
- `dev-{branch}` - Development branch builds
- `pr-{number}` - Pull request builds
- `commit-{sha}` - Specific commit builds

### Tagging Examples
```bash
# Production release
./docker-build-push.sh v1.0.0

# Development build
./docker-build-push.sh dev-$(git branch --show-current)

# Commit-specific build
./docker-build-push.sh commit-$(git rev-parse --short HEAD)

# Feature branch
./docker-build-push.sh feature-new-analytics
```

## 📊 Container Registry Management

### View Images and Tags
```bash
# List repositories
az acr repository list --name $ACR_NAME

# List tags for repository
az acr repository show-tags \
  --name $ACR_NAME \
  --repository fastapi-app

# Show image details
az acr repository show \
  --name $ACR_NAME \
  --repository fastapi-app:latest
```

### Image Cleanup
```bash
# Delete specific tag
az acr repository delete \
  --name $ACR_NAME \
  --repository fastapi-app:old-tag \
  --yes

# Delete untagged manifests
az acr repository delete \
  --name $ACR_NAME \
  --repository fastapi-app \
  --untagged \
  --yes

# Purge old images (keep last 10)
az acr repository delete \
  --name $ACR_NAME \
  --repository fastapi-app \
  --orderby time_desc \
  --keep 10 \
  --yes
```

## 🔒 Security Configuration

### Managed Identity Authentication
- **Type**: System-assigned Managed Identity
- **Scope**: Container App access to ACR
- **Role**: AcrPull (minimal required permissions)
- **Benefits**: No stored credentials, automatic token refresh

### RBAC Configuration
```hcl
# Terraform configuration
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
```

### Network Security
- **Private Endpoints**: Available in Standard/Premium SKUs
- **Firewall Rules**: IP restriction configuration
- **Virtual Network**: VNet integration support

### Image Scanning
```bash
# Enable security scanning (Premium SKU)
az acr task create \
  --registry $ACR_NAME \
  --name security-scan \
  --image fastapi-app:{{.Run.ID}} \
  --context . \
  --file Dockerfile \
  --commit-trigger-enabled true
```

## 🔍 Container Monitoring

### Health Checks
```bash
# Container health status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Health check logs
docker logs --tail 50 container-name

# Execute health check manually
docker exec container-name curl -f http://localhost:8000/health
```

### Container Logs
```bash
# View real-time logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow

# Export logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --output table > container-logs.txt
```

### Resource Monitoring
```bash
# Container resource usage
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "properties.template.containers[0].resources"

# Scaling metrics
az monitor metrics list \
  --resource /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.App/containerapps/{app} \
  --metric "Requests"
```

## 🚀 CI/CD Integration

### GitHub Actions Example
```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build and Push
        run: |
          cd azure-scripts
          ./docker-build-push.sh ${{ github.sha }}
      
      - name: Update Container App
        run: |
          az containerapp update \
            --name $(terraform output -raw container_app_name) \
            --resource-group $(terraform output -raw resource_group_name) \
            --image $(terraform output -raw container_registry_login_server)/fastapi-app:${{ github.sha }}
```

### Azure DevOps Pipeline
```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzureCLI@2
  displayName: 'Build and Push Docker Image'
  inputs:
    azureSubscription: 'azure-connection'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: 'azure-scripts/docker-build-push.sh'
    arguments: '$(Build.BuildId)'
```

## ⚡ Performance Optimization

### Image Size Optimization
```dockerfile
# Multi-stage build example
FROM python:3.11-slim as builder
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY app/ .
ENV PATH=/root/.local/bin:$PATH
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Build Cache Optimization
```bash
# Use BuildKit for better caching
export DOCKER_BUILDKIT=1

# Build with cache from registry
docker build \
  --cache-from $ACR_LOGIN_SERVER/fastapi-app:latest \
  -t $ACR_LOGIN_SERVER/fastapi-app:new-tag .
```

### Container Runtime Optimization
```yaml
# Container App configuration
resources:
  cpu: 0.5
  memory: "1Gi"
scale:
  minReplicas: 0
  maxReplicas: 10
  rules:
  - name: "http-scaling"
    http:
      metadata:
        concurrentRequests: 100
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Build Failures
```bash
# Check Docker daemon
docker version

# Clean build cache
docker builder prune

# Build with verbose output
docker build --progress=plain -t test-image .
```

#### 2. Push/Pull Failures
```bash
# Check ACR login
az acr login --name $ACR_NAME

# Verify credentials
az acr credential show --name $ACR_NAME

# Test connectivity
docker pull $ACR_LOGIN_SERVER/fastapi-app:latest
```

#### 3. Container Startup Issues
```bash
# Check container logs
docker logs container-name

# Run with shell access
docker run -it --entrypoint /bin/bash image-name

# Check health endpoint
curl -f http://localhost:8000/health
```

#### 4. ACR Authentication Issues
```bash
# Check Managed Identity status
az containerapp identity show \
  --name <container-app-name> \
  --resource-group <resource-group>

# Verify role assignments
az role assignment list \
  --assignee <managed-identity-id> \
  --scope <acr-resource-id>
```

### Debugging Commands
```bash
# Container inspection
docker inspect container-name

# Process monitoring
docker exec container-name ps aux

# Network debugging
docker exec container-name netstat -tlnp

# File system check
docker exec container-name ls -la /data
```

## 📊 Container Metrics

### Performance Metrics
- **Startup Time**: Container initialization duration
- **Memory Usage**: Runtime memory consumption
- **CPU Utilization**: Processing load metrics
- **Network I/O**: Data transfer statistics

### Monitoring Tools
```bash
# Docker stats
docker stats container-name

# Azure Monitor metrics
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "CpuPercentage,MemoryPercentage"
```

## 🔗 Related Documentation

- [Azure Deployment Guide](azure-deployment.md)
- [Terraform Infrastructure](terraform.md)
- [Security Configuration](security.md)
- [Troubleshooting Guide](troubleshooting.md)

## 📚 Additional Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
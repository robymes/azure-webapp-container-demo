# Azure Kubernetes Service (AKS) Deployment Summary

## Architecture Overview

This deployment creates a complete FastAPI application infrastructure on Azure Kubernetes Service (AKS) with the following components:

### Infrastructure Components

1. **Resource Group**: Contains all Azure resources
2. **Azure Container Registry (ACR)**: Stores Docker images
3. **Azure Kubernetes Service (AKS)**: Orchestrates containerized applications
4. **Storage Account**: Provides persistent storage with file shares
5. **Log Analytics Workspace**: Centralized logging and monitoring

### Kubernetes Resources

1. **FastAPI Deployment**: Main application deployment with 2 replicas
2. **Services**: 
   - ClusterIP service for internal communication
   - LoadBalancer service for external access
3. **ConfigMap**: Contains application configuration
4. **Secrets**: Contains ACR credentials and Azure storage keys
5. **PersistentVolumeClaim**: Mounts Azure File Share storage
6. **StorageClass**: Configures Azure Files CSI driver

## Deployment Process

### Prerequisites
- Azure CLI installed and authenticated
- Docker installed
- Terraform installed
- kubectl installed

### Step 1: Build and Push Docker Image
```bash
./docker-build-push.sh
```

### Step 2: Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Configure kubectl
```bash
az aks get-credentials --resource-group <resource-group> --name <aks-cluster-name>
```

### Step 4: Verify Deployment
```bash
kubectl get pods
kubectl get services
kubectl get pvc
```

## Key Features

- **Scalable**: AKS provides automatic scaling capabilities
- **Persistent Storage**: Azure File Share integration for data persistence
- **Secure**: RBAC-enabled with system-assigned managed identity
- **Load Balanced**: Built-in load balancing through Kubernetes services
- **Health Monitoring**: Liveness and readiness probes configured

## Configuration

The application is configured through:
- Environment variables in the Kubernetes deployment
- ConfigMap for non-sensitive configuration (`/app/config/config.toml`)
- Secrets for sensitive data (ACR credentials, storage keys)
- Azure File Share mount at `/data` for persistent data

## External Storage Access

The deployment includes Azure File Share integration with external access capabilities:

```bash
# Test connectivity
./external-storage-access.sh test

# List files
./external-storage-access.sh list

# Upload files
./external-storage-access.sh upload local-file.txt

# Download files
./external-storage-access.sh download remote-file.txt
```

## Security Features

- **Managed Identity**: System-assigned identity for AKS cluster
- **RBAC**: Role-based access control enabled
- **ACR Integration**: Secure image pulling with role assignments
- **Storage Security**: Infrastructure encryption enabled
- **Network Security**: Configurable network access restrictions

## Monitoring and Logs

- **Application logs**: `kubectl logs -f deployment/fastapi-app`
- **Pod status**: `kubectl get pods -o wide`
- **Service status**: `kubectl get services`
- **Storage status**: `kubectl get pvc`

## Resource Configuration

### AKS Cluster
- **Node Pool**: 1 node, Standard_B2s VM size
- **Kubernetes Version**: 1.28
- **Network Plugin**: kubenet
- **DNS Prefix**: Based on project name

### Application Deployment
- **Replicas**: 2 pods for high availability
- **CPU Limits**: 500m per container
- **Memory Limits**: 512Mi per container
- **Health Checks**: Configured liveness and readiness probes

### Storage
- **File Share Quota**: 3GB (configurable)
- **Storage Class**: Azure Files with Standard_LRS
- **Mount Options**: Optimized for Linux containers
- **Access Mode**: ReadWriteMany

## Accessing the Application

The application is accessible via:
1. **LoadBalancer Service**: External IP provided by Azure Load Balancer
2. **Health Endpoint**: `/health` - Application health check
3. **Ready Endpoint**: `/ready` - Application readiness check

Get the external IP:
```bash
kubectl get service fastapi-loadbalancer
```

## Cleanup

To remove all resources:
```bash
./terraform-cleanup.sh
```

This will destroy the entire infrastructure including the AKS cluster, storage, and all associated resources.

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check image pull secrets and ACR permissions
2. **Storage mount issues**: Verify file share exists and storage secret is correct
3. **External access issues**: Check LoadBalancer service configuration

### Debugging Commands

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check deployment status
kubectl describe deployment fastapi-app

# Check storage mounting
kubectl describe pvc fastapi-pvc

# Check service endpoints
kubectl get endpoints
```

## Migration from Container Apps

This deployment has been migrated from Azure Container Apps to AKS to provide:
- Better scalability options
- More control over networking
- Enhanced monitoring capabilities
- Direct Kubernetes resource management
- Improved storage integration

All Container Apps-specific configurations have been removed and replaced with Kubernetes-native resources.
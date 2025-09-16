# Azure Kubernetes Service (AKS) Deployment Scripts

This directory contains scripts and Terraform configurations for deploying a FastAPI application on Azure Kubernetes Service (AKS).

## Files Overview

### Terraform Configuration
- `main.tf` - Main infrastructure definition (AKS, ACR, Storage, Kubernetes resources)
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values after deployment
- `provider.tf` - Azure provider configuration

### Deployment Scripts
- `docker-build-push.sh` - Builds Docker image and pushes to Azure Container Registry
- `external-storage-access.sh` - Configures external access to Azure Storage
- `terraform-cleanup.sh` - Destroys all Terraform-managed resources

### Documentation
- `DEPLOYMENT-SUMMARY.md` - Detailed deployment architecture and process
- `README.md` - This file

## Quick Start

1. **Configure Variables**
   ```bash
   # Edit variables.tf or create terraform.tfvars
   cp variables.tf terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Build and Push Docker Image**
   ```bash
   ./docker-build-push.sh
   ```

3. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access Your Application**
   ```bash
   # Get AKS credentials
   az aks get-credentials --resource-group <resource-group> --name <aks-cluster-name>
   
   # Check deployment status
   kubectl get pods
   kubectl get services
   kubectl get pvc
   
   # Get external IP
   kubectl get service fastapi-loadbalancer
   ```

## Prerequisites

- Azure CLI (authenticated with `az login`)
- Docker
- Terraform >= 1.0
- kubectl

## Architecture

The deployment creates:
- **AKS Cluster**: Managed Kubernetes service with system-assigned identity
- **Azure Container Registry**: For storing Docker images
- **Azure Storage Account**: For persistent data storage via Azure Files
- **Kubernetes Resources**: Deployments, services, persistent volumes, and configuration

## Key Features

### Infrastructure
- **Scalable AKS cluster** with configurable node pools
- **Azure Container Registry** with admin access for deployment
- **Azure File Share** integration for persistent storage
- **LoadBalancer service** for external application access

### Security
- **System-assigned managed identity** for AKS
- **Role-based access control** (RBAC) enabled
- **ACR integration** with proper role assignments
- **Infrastructure encryption** for storage account
- **Configurable network access restrictions**

### Application Deployment
- **FastAPI application** with 2 replicas for high availability
- **Health and readiness probes** for reliable operations
- **ConfigMap and Secrets** for configuration management
- **Persistent volume mounting** at `/data` directory

## Configuration

Key configuration files:
- `terraform.tfvars` - Infrastructure variables
- Kubernetes manifests are embedded in `main.tf`
- Application configuration via ConfigMap at `/app/config/config.toml`
- Storage credentials via Kubernetes secrets

## External Storage Access

Access the Azure File Share externally using the storage access script:

```bash
# Test connectivity
./external-storage-access.sh test

# List files in the share
./external-storage-access.sh list

# Upload a local file
./external-storage-access.sh upload ./local-file.txt remote-file.txt

# Download a remote file
./external-storage-access.sh download remote-file.txt ./local-file.txt

# Create directories
./external-storage-access.sh mkdir uploads

# Get file information
./external-storage-access.sh info remote-file.txt
```

## Monitoring

### Kubernetes Monitoring
```bash
# Check pod status
kubectl get pods -o wide

# View application logs
kubectl logs -f deployment/fastapi-app

# Check service endpoints
kubectl get services
kubectl get endpoints

# Monitor persistent storage
kubectl get pvc
kubectl get pv
```

### Resource Monitoring
```bash
# Check node status
kubectl get nodes

# View resource usage
kubectl top nodes
kubectl top pods
```

## Scaling

### Manual Scaling
```bash
# Scale the application
kubectl scale deployment fastapi-app --replicas=3

# Scale cluster nodes (if needed)
az aks scale --resource-group <resource-group> --name <aks-cluster-name> --node-count 2
```

## Troubleshooting

### Common Issues

1. **Image pull failures**: Check ACR permissions and secret configuration
2. **Pod startup issues**: Verify resource limits and health probe configurations
3. **Storage mounting problems**: Check file share existence and storage secrets
4. **External access issues**: Verify LoadBalancer service and Azure Load Balancer configuration

### Debug Commands

```bash
# Describe resources for detailed information
kubectl describe pod <pod-name>
kubectl describe deployment fastapi-app
kubectl describe service fastapi-loadbalancer
kubectl describe pvc fastapi-pvc

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Test connectivity
kubectl exec -it <pod-name> -- /bin/bash
```

## Cleanup

To remove all resources:
```bash
./terraform-cleanup.sh
```

**Warning**: This will permanently delete the AKS cluster and all associated resources including data.

## Migration Notes

This deployment has been migrated from Azure Container Apps to AKS to provide:
- Enhanced scalability and control
- Better integration with Kubernetes ecosystem
- More flexible networking options
- Direct access to Kubernetes resources and features

All Container Apps-specific references have been removed and replaced with AKS/Kubernetes equivalents.
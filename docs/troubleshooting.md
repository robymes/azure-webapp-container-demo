# 🐛 Troubleshooting & Maintenance Documentation

This document provides comprehensive troubleshooting guides, common issues, maintenance procedures, and diagnostic tools for the FastAPI Azure Container Apps deployment.

## Overview

This guide covers troubleshooting for all components of the system including Container Apps, Azure Container Registry, Storage, Terraform infrastructure, and application-specific issues.

## 🔧 Quick Diagnostic Commands

### System Health Check
```bash
# Complete system status check
cd azure-scripts

# Check Terraform outputs
terraform output

# Check Container App status
az containerapp show \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "{Status:properties.provisioningState,Replicas:properties.runningStatus,URL:properties.configuration.ingress.fqdn}"

# Test application endpoints
curl -f https://$(terraform output -raw container_app_url)/health
```

### Resource Status Overview
```bash
# Check all resources in resource group
az resource list \
  --resource-group $(terraform output -raw resource_group_name) \
  --output table

# Check Container App revisions
az containerapp revision list \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --output table
```

## 🚨 Common Issues and Solutions

### 1. Container App Startup Failures

#### Symptoms
- Container app shows "Failed" or "Pending" status
- Application not responding to requests
- Health check endpoints timing out

#### Diagnostic Commands
```bash
# Check Container App status
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "properties.provisioningState"

# View container logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --tail 100

# Check revision status
az containerapp revision list \
  --name <container-app-name> \
  --resource-group <resource-group>
```

#### Common Causes and Solutions

**A. Image Pull Failures**
```bash
# Verify ACR access
az acr check-health --name $(terraform output -raw container_registry_name)

# Check Managed Identity permissions
az role assignment list \
  --assignee $(az containerapp identity show --name <container-app-name> --resource-group <resource-group> --query principalId -o tsv)

# Solution: Fix ACR permissions
az role assignment create \
  --assignee <managed-identity-principal-id> \
  --role "AcrPull" \
  --scope <acr-resource-id>
```

**B. Application Configuration Issues**
```bash
# Check environment variables
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "properties.template.containers[0].env"

# Check resource allocation
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "properties.template.containers[0].resources"
```

**C. Storage Mount Issues**
```bash
# Verify storage configuration
az containerapp env storage list \
  --name <environment-name> \
  --resource-group <resource-group>

# Check storage account accessibility
az storage account show \
  --name <storage-account-name> \
  --resource-group <resource-group> \
  --query "{SharedKeyAccess:allowSharedKeyAccess,PublicAccess:publicNetworkAccess}"
```

### 2. Image Push/Pull Failures

#### Symptoms
- Docker push commands failing
- Container App unable to pull images
- "authentication required" errors

#### Diagnostic Commands
```bash
# Test ACR login
az acr login --name $(terraform output -raw container_registry_name)

# Check ACR repositories
az acr repository list --name $(terraform output -raw container_registry_name)

# Test image pull
docker pull $(terraform output -raw container_registry_login_server)/fastapi-app:latest
```

#### Solutions

**A. Authentication Issues**
```bash
# Re-login to ACR
az acr login --name $(terraform output -raw container_registry_name)

# Check ACR credentials
az acr credential show --name $(terraform output -raw container_registry_name)

# For Managed Identity issues
az containerapp identity assign \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --system-assigned
```

**B. Network Connectivity Issues**
```bash
# Check ACR endpoint connectivity
nslookup $(terraform output -raw container_registry_login_server)

# Test ACR connectivity from Container App
az containerapp exec \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --command "curl -v https://$(terraform output -raw container_registry_login_server)/v2/"
```

**C. Permission Issues**
```bash
# Verify Container App has AcrPull role
az role assignment create \
  --assignee $(az containerapp identity show --name <container-app-name> --resource-group <resource-group> --query principalId -o tsv) \
  --role "AcrPull" \
  --scope $(az acr show --name $(terraform output -raw container_registry_name) --query id -o tsv)
```

### 3. Storage Access Issues

#### Symptoms
- Files not persisting between container restarts
- Permission denied errors when accessing `/data`
- Storage mount not visible in container

#### Diagnostic Commands
```bash
# Check storage mount configuration
az containerapp env storage show \
  --name <environment-name> \
  --resource-group <resource-group> \
  --storage-name azure-files-storage

# Verify storage account configuration
az storage account show \
  --name $(terraform output -raw storage_account_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "{NetworkRules:networkRuleSet,SharedKeyAccess:allowSharedKeyAccess}"

# Test file operations
az containerapp exec \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --command "ls -la /data && touch /data/test.txt && ls -la /data/test.txt"
```

#### Solutions

**A. Managed Identity Storage Access**
```bash
# Grant storage permissions to Managed Identity
az role assignment create \
  --assignee $(az containerapp identity show --name <container-app-name> --resource-group <resource-group> --query principalId -o tsv) \
  --role "Storage File Data SMB Share Contributor" \
  --scope $(az storage account show --name $(terraform output -raw storage_account_name) --query id -o tsv)
```

**B. Storage Mount Configuration**
```bash
# Re-configure storage mount
az containerapp env storage set \
  --name <environment-name> \
  --resource-group <resource-group> \
  --storage-name azure-files-storage \
  --azure-file-account-name $(terraform output -raw storage_account_name) \
  --azure-file-share-name container-data \
  --access-mode ReadWrite
```

**C. Network Access Issues**
```bash
# Check if storage allows Azure services
az storage account update \
  --name $(terraform output -raw storage_account_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --bypass AzureServices
```

### 4. Terraform Deployment Issues

#### Symptoms
- Terraform apply failures
- Resource creation errors
- State corruption issues

#### Diagnostic Commands
```bash
# Validate Terraform configuration
terraform validate

# Check Terraform state
terraform show

# Verify Azure CLI authentication
az account show

# Check resource quotas
az vm list-usage --location "West Europe" --query "[?currentValue>0]" --output table
```

#### Common Solutions

**A. Authentication Issues**
```bash
# Re-authenticate with Azure
az login
az account set --subscription <subscription-id>

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

**B. Resource Conflicts**
```bash
# Check if resources already exist
az resource list --resource-group <resource-group-name>

# Import existing resources
terraform import azurerm_resource_group.main /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
```

**C. State Lock Issues**
```bash
# Force unlock if stuck
terraform force-unlock <lock-id>

# Refresh state
terraform refresh
```

### 5. Application Performance Issues

#### Symptoms
- Slow response times
- High memory usage
- CPU throttling
- Request timeouts

#### Diagnostic Commands
```bash
# Check Container App metrics
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "Requests,CpuPercentage,MemoryPercentage" \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z

# View scaling behavior
az containerapp revision list \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "[].{Name:name,Replicas:properties.replicas,Active:properties.active}"

# Check application logs for errors
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --tail 200 | grep -i error
```

#### Solutions

**A. Resource Allocation**
```bash
# Increase CPU and memory
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --cpu 1.0 \
  --memory 2Gi

# Adjust scaling parameters
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --min-replicas 2 \
  --max-replicas 10
```

**B. Database Performance**
```python
# Optimize DuckDB queries
import duckdb

conn = duckdb.connect("/data/ecommerce_analytics.ducklake")

# Add indexes for frequently queried columns
conn.execute("CREATE INDEX idx_customers_country ON customers(country);")
conn.execute("CREATE INDEX idx_orders_date ON orders(order_date);")

# Analyze query performance
result = conn.execute("EXPLAIN ANALYZE SELECT * FROM customers WHERE country = 'United States';")
print(result.fetchall())
```

**C. Application Optimization**
```python
# Add caching to FastAPI endpoints
from functools import lru_cache
import asyncio

@lru_cache(maxsize=100)
def get_analytics_data():
    # Expensive computation
    return analytics_result

# Add request timeout
from fastapi import FastAPI, Request
import signal

app = FastAPI()

def timeout_handler(signum, frame):
    raise TimeoutError("Request timeout")

@app.middleware("http")
async def timeout_middleware(request: Request, call_next):
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(30)  # 30 second timeout
    try:
        response = await call_next(request)
        return response
    finally:
        signal.alarm(0)
```

## 🔍 Advanced Diagnostics

### Container App Deep Dive
```bash
# Get detailed Container App information
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --output json > containerapp-details.json

# Check revision history
az containerapp revision list \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --output table

# Monitor real-time logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow
```

### Network Connectivity Testing
```bash
# Test external connectivity from container
az containerapp exec \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --command "curl -v https://httpbin.org/ip"

# Test internal Azure service connectivity
az containerapp exec \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --command "nslookup $(terraform output -raw storage_account_name).file.core.windows.net"

# Check DNS resolution
az containerapp exec \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --command "cat /etc/resolv.conf"
```

### Storage Diagnostics
```bash
# Check storage account health
az storage account show \
  --name $(terraform output -raw storage_account_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "{ProvisioningState:provisioningState,StatusOfPrimary:statusOfPrimary}"

# List files in storage share
az storage file list \
  --account-name $(terraform output -raw storage_account_name) \
  --share-name container-data \
  --auth-mode login

# Check storage metrics
az monitor metrics list \
  --resource $(az storage account show --name $(terraform output -raw storage_account_name) --query id -o tsv) \
  --metric "Transactions,Ingress,Egress"
```

## 🛠️ Maintenance Procedures

### Regular Health Checks
```bash
#!/bin/bash
# health-check.sh - Regular maintenance script

echo "=== FastAPI Health Check $(date) ==="

# Check all resources
echo "1. Checking resource status..."
az resource list \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "[].{Name:name,Type:type,Status:properties.provisioningState}" \
  --output table

# Test application endpoints
echo "2. Testing application endpoints..."
APP_URL=$(terraform output -raw container_app_url)
curl -f https://$APP_URL/health || echo "Health endpoint failed"
curl -f https://$APP_URL/ || echo "Root endpoint failed"

# Check logs for errors
echo "3. Checking recent errors..."
az containerapp logs show \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --tail 50 | grep -i error | tail -10

echo "=== Health Check Complete ==="
```

### Database Maintenance
```python
# database_maintenance.py
import duckdb
import os
from datetime import datetime

def maintain_database():
    """Perform regular database maintenance"""
    conn = duckdb.connect("/data/ecommerce_analytics.ducklake")
    
    print(f"Starting database maintenance at {datetime.now()}")
    
    # Vacuum database to reclaim space
    conn.execute("VACUUM;")
    print("Database vacuumed")
    
    # Update table statistics
    conn.execute("ANALYZE;")
    print("Table statistics updated")
    
    # Check database integrity
    result = conn.execute("PRAGMA integrity_check;").fetchone()
    print(f"Integrity check: {result[0]}")
    
    # Get database size
    size_result = conn.execute("PRAGMA database_size;").fetchone()
    print(f"Database size: {size_result[0]} bytes")
    
    conn.close()
    print("Database maintenance completed")

if __name__ == "__main__":
    maintain_database()
```

### Log Cleanup
```bash
# log-cleanup.sh - Clean up old logs
#!/bin/bash

echo "Cleaning up application logs..."

# Archive old logs (older than 30 days)
find /data/logs -name "*.log" -mtime +30 -exec gzip {} \;

# Remove very old archived logs (older than 90 days)
find /data/logs -name "*.log.gz" -mtime +90 -delete

# Clean up temporary files
find /data/temp -type f -mtime +7 -delete

echo "Log cleanup completed"
```

### Security Updates
```bash
# security-update.sh - Regular security updates
#!/bin/bash

echo "Performing security updates..."

# Update base image (rebuild container)
cd azure-scripts
./docker-build-push.sh security-update-$(date +%Y%m%d)

# Update Container App with new image
az containerapp update \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --image $(terraform output -raw container_registry_login_server)/fastapi-app:security-update-$(date +%Y%m%d)

# Check for Azure security recommendations
az security assessment list \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "[?properties.status.severity=='High'].{Name:displayName,Status:properties.status.code}" \
  --output table

echo "Security updates completed"
```

## 🚨 Emergency Procedures

### Complete System Recovery
```bash
# emergency-recovery.sh
#!/bin/bash

echo "=== EMERGENCY RECOVERY PROCEDURE ==="

# 1. Stop current application
echo "1. Stopping current application..."
az containerapp update \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --min-replicas 0 \
  --max-replicas 0

# 2. Deploy known good version
echo "2. Deploying last known good version..."
LAST_GOOD_TAG="v1.0.0"  # Update this with your last known good version
az containerapp update \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --image $(terraform output -raw container_registry_login_server)/fastapi-app:$LAST_GOOD_TAG

# 3. Restore scaling
echo "3. Restoring normal scaling..."
az containerapp update \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --min-replicas 1 \
  --max-replicas 5

# 4. Verify recovery
echo "4. Verifying recovery..."
sleep 30
curl -f https://$(terraform output -raw container_app_url)/health

echo "=== RECOVERY COMPLETE ==="
```

### Backup and Restore
```bash
# backup-system.sh
#!/bin/bash

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/data/backups/$BACKUP_DATE"

echo "Creating system backup: $BACKUP_DIR"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
cp /data/ecommerce_analytics.ducklake $BACKUP_DIR/

# Backup configuration
cp /app/config.toml $BACKUP_DIR/

# Backup important data files
tar -czf $BACKUP_DIR/data_files.tar.gz /data/lakehouse/ /data/archive/

# Export current Container App configuration
az containerapp show \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  > $BACKUP_DIR/containerapp-config.json

# Export Terraform state
cp terraform.tfstate $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
```

## 📊 Monitoring and Alerting

### Performance Monitoring
```bash
# performance-monitor.sh
#!/bin/bash

# Monitor key metrics
echo "=== Performance Monitoring ==="

# CPU and Memory usage
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "CpuPercentage,MemoryPercentage" \
  --interval PT1M \
  --query "value[].{Metric:name.value,Average:average,Maximum:maximum}" \
  --output table

# Request metrics
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "Requests" \
  --interval PT5M \
  --query "value[].{Time:timeStamp,Count:total}" \
  --output table

# Storage metrics
az monitor metrics list \
  --resource $(az storage account show --name $(terraform output -raw storage_account_name) --query id -o tsv) \
  --metric "Transactions,SuccessE2ELatency" \
  --interval PT5M \
  --output table
```

### Custom Health Check Script
```python
# health_monitor.py
import requests
import json
import time
import sys
from datetime import datetime

def check_health():
    """Comprehensive health check"""
    health_data = {
        "timestamp": datetime.now().isoformat(),
        "checks": {}
    }
    
    # Check main application
    try:
        response = requests.get("https://your-app.azurecontainerapps.io/health", timeout=10)
        health_data["checks"]["app_health"] = {
            "status": "healthy" if response.status_code == 200 else "unhealthy",
            "response_time": response.elapsed.total_seconds(),
            "status_code": response.status_code
        }
    except Exception as e:
        health_data["checks"]["app_health"] = {
            "status": "unhealthy",
            "error": str(e)
        }
    
    # Check database functionality
    try:
        response = requests.get("https://your-app.azurecontainerapps.io/query", timeout=30)
        health_data["checks"]["database"] = {
            "status": "healthy" if response.status_code == 200 else "unhealthy",
            "response_time": response.elapsed.total_seconds()
        }
    except Exception as e:
        health_data["checks"]["database"] = {
            "status": "unhealthy",
            "error": str(e)
        }
    
    # Check file operations
    try:
        test_data = {"content": f"Health check {datetime.now()}", "filename": "health_check.txt"}
        response = requests.post("https://your-app.azurecontainerapps.io/write-file", 
                               json=test_data, timeout=10)
        health_data["checks"]["storage"] = {
            "status": "healthy" if response.status_code == 200 else "unhealthy",
            "response_time": response.elapsed.total_seconds()
        }
    except Exception as e:
        health_data["checks"]["storage"] = {
            "status": "unhealthy",
            "error": str(e)
        }
    
    return health_data

if __name__ == "__main__":
    health = check_health()
    print(json.dumps(health, indent=2))
    
    # Exit with error code if any check failed
    failed_checks = [check for check, data in health["checks"].items() 
                    if data.get("status") != "healthy"]
    
    if failed_checks:
        print(f"Failed checks: {failed_checks}", file=sys.stderr)
        sys.exit(1)
```

## 🔧 Development and Testing Tools

### Local Development Troubleshooting
```bash
# Local development issues
docker-compose logs fastapi-app

# Build issues
docker build --no-cache -t fastapi-test .

# Run with debug mode
docker run -it --rm \
  -p 8000:8000 \
  -v $(pwd)/data:/data \
  -e PYTHONPATH=/app \
  -e PYTHONUNBUFFERED=1 \
  -e DEBUG=true \
  fastapi-test

# Test specific endpoints
curl -v http://localhost:8000/health
curl -X POST "http://localhost:8000/write-file" \
  -H "Content-Type: application/json" \
  -d '{"content":"test","filename":"debug.txt"}'
```

### API Testing Scripts
```bash
# api-test-suite.sh
#!/bin/bash

BASE_URL=${1:-"http://localhost:8000"}
echo "Testing API endpoints at: $BASE_URL"

# Test health endpoint
echo "1. Testing health endpoint..."
if curl -f $BASE_URL/health; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    exit 1
fi

# Test file operations
echo "2. Testing file operations..."
if curl -X POST "$BASE_URL/write-file" \
    -H "Content-Type: application/json" \
    -d '{"content":"API test","filename":"api_test.txt"}'; then
    echo "✓ File write passed"
else
    echo "✗ File write failed"
    exit 1
fi

# Test data warehouse
echo "3. Testing data warehouse..."
if curl -X POST "$BASE_URL/init-dwh"; then
    echo "✓ DWH initialization passed"
else
    echo "✗ DWH initialization failed"
    exit 1
fi

echo "All API tests passed!"
```

## 🔗 Related Documentation

- [API Documentation](api.md)
- [Terraform Infrastructure](terraform.md)
- [Azure Deployment](azure-deployment.md)
- [Docker & Containers](docker.md)
- [Security Configuration](security.md)
- [Data Warehouse Guide](data-warehouse.md)

## 📞 Support Resources

### Azure Support Commands
```bash
# Check Azure service health
az rest --method get \
  --url "https://management.azure.com/subscriptions/{subscription-id}/providers/Microsoft.ResourceHealth/availabilityStatuses" \
  --query "value[?properties.availabilityState!='Available']"

# Get support ticket information
az support tickets list --output table

# Create support ticket (if needed)
az support tickets create \
  --ticket-name "FastAPI Container Apps Issue" \
  --title "Container App Deployment Issue" \
  --description "Detailed description of the issue" \
  --problem-classification-id "/providers/Microsoft.Support/services/06bfd9d3-516b-d5c6-5802-169c800dec89/problemClassifications/32570a2e-8c08-8b8a-7b3d-3b3c7c3f3c3f"
```

### Community Resources
- [Azure Container Apps GitHub](https://github.com/microsoft/azure-container-apps)
- [FastAPI GitHub Issues](https://github.com/tiangolo/fastapi/issues)
- [DuckDB GitHub Issues](https://github.com/duckdb/duckdb/issues)
- [Terraform Azure Provider Issues](https://github.com/hashicorp/terraform-provider-azurerm/issues)

### Documentation Links
- [Azure Container Apps Troubleshooting](https://docs.microsoft.com/en-us/azure/container-apps/troubleshooting)
- [Azure Storage Troubleshooting](https://docs.microsoft.com/en-us/azure/storage/common/storage-monitoring-diagnosing-troubleshooting)
- [Terraform Troubleshooting](https://www.terraform.io/docs/configuration/debugging.html)
- [Docker Troubleshooting](https://docs.docker.com/config/troubleshooting/)

## 📝 Issue Reporting Template

When reporting issues, include the following information:

```
### Environment Information
- Azure Region: 
- Subscription ID: 
- Resource Group: 
- Container App Name: 

### Issue Description
[Detailed description of the issue]

### Steps to Reproduce
1. 
2. 
3. 

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Error Messages
```
[Include any error messages]
```

### Diagnostic Output
```
[Include output from diagnostic commands]
```

### Additional Context
[Any additional information that might be helpful]
```

This template helps ensure all necessary information is provided for effective troubleshooting.
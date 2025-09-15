# 🔌 API Documentation

This document provides comprehensive information about the FastAPI application endpoints, usage examples, and integration details.

## Overview

The FastAPI application provides REST endpoints for:
- Health monitoring and system status
- File operations with persistent storage
- Data warehouse initialization and analytics
- Interactive API documentation

## 🚀 Base Endpoints

### Health Check Endpoints

#### `GET /`
Basic health check endpoint.

**Response:**
```json
{
  "message": "FastAPI is running on Azure Container Apps!"
}
```

#### `GET /health`
Detailed health check with system status.

**Response:**
```json
{
  "status": "healthy",
  "storage_accessible": true,
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

## 📁 File Operations

### Write File
#### `POST /write-file`
Write content to persistent storage.

**Request Body:**
```json
{
  "content": "Hello World from Azure Container Apps!",
  "filename": "example.txt"
}
```

**Response:**
```json
{
  "message": "File 'example.txt' written successfully",
  "filepath": "/data/example.txt",
  "size": 42
}
```

**Example:**
```bash
curl -X POST "https://your-app.azurecontainerapps.io/write-file" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello World!","filename":"test.txt"}'
```

### List Files
#### `GET /list-files`
List all files in persistent storage.

**Response:**
```json
{
  "files": [
    {
      "name": "example.txt",
      "size": 42,
      "modified": "2024-01-15T10:30:00Z"
    },
    {
      "name": "data.json",
      "size": 1024,
      "modified": "2024-01-15T09:15:00Z"
    }
  ],
  "total_files": 2
}
```

**Example:**
```bash
curl https://your-app.azurecontainerapps.io/list-files
```

### Read File
#### `GET /read-file/{filename}`
Read file content from persistent storage.

**Parameters:**
- `filename` (path): Name of the file to read

**Response:**
```json
{
  "filename": "example.txt",
  "content": "Hello World from Azure Container Apps!",
  "size": 42,
  "modified": "2024-01-15T10:30:00Z"
}
```

**Example:**
```bash
curl https://your-app.azurecontainerapps.io/read-file/example.txt
```

## 📊 Data Warehouse Endpoints

### Initialize Data Warehouse
#### `POST /init-dwh`
Initialize DuckDB data warehouse with sample e-commerce data.

**Response:**
```json
{
  "message": "Data warehouse initialized successfully",
  "database_path": "/data/ecommerce_analytics.ducklake",
  "tables_created": [
    "customers",
    "products", 
    "orders",
    "order_items",
    "product_reviews"
  ],
  "total_records": 15000
}
```

**Example:**
```bash
curl -X POST https://your-app.azurecontainerapps.io/init-dwh
```

### Execute Analytics Query
#### `GET /query`
Execute pre-built analytics queries on e-commerce data.

**Response:**
```json
{
  "query": "Customer Demographics by Country",
  "results": [
    {
      "country": "United States", 
      "total_customers": 2543,
      "male_customers": 1289,
      "female_customers": 1254,
      "total_orders": 5821,
      "avg_order_value": 156.78
    },
    {
      "country": "United Kingdom",
      "total_customers": 1876,
      "male_customers": 945,
      "female_customers": 931,
      "total_orders": 4234,
      "avg_order_value": 142.33
    }
  ],
  "execution_time_ms": 45,
  "total_rows": 10
}
```

**Example:**
```bash
curl https://your-app.azurecontainerapps.io/query
```

## 🔧 Configuration

### Environment Variables
The application uses these environment variables:

```bash
PYTHONPATH=/app
PYTHONUNBUFFERED=1
```

### Storage Configuration
- **Mount Path**: `/data`
- **Type**: Azure Files (SMB)
- **Authentication**: Managed Identity

### TOML Configuration
Application configuration via [`config.toml`](../app/config.toml):

```toml
[database]
ducklake_path = "/data/ecommerce_analytics.ducklake"
data_path = "/data/lakehouse/"

[parquet_files]
base_path = "/data/archive/parquet/"

[analytics]
top_countries_limit = 10
```

## 📋 API Testing

### Automated Testing Script
Use the provided test script for comprehensive API testing:

```bash
# Test locally
./test-api.sh

# Test deployed application  
./test-api.sh https://your-app.azurecontainerapps.io

# Show help
./test-api.sh --help
```

### Manual Testing Workflow

1. **Health Check**
   ```bash
   curl https://your-app.azurecontainerapps.io/health
   ```

2. **Initialize Data Warehouse**
   ```bash
   curl -X POST https://your-app.azurecontainerapps.io/init-dwh
   ```

3. **Write Test File**
   ```bash
   curl -X POST "https://your-app.azurecontainerapps.io/write-file" \
     -H "Content-Type: application/json" \
     -d '{"content":"Test data","filename":"test.txt"}'
   ```

4. **List Files**
   ```bash
   curl https://your-app.azurecontainerapps.io/list-files
   ```

5. **Read File**
   ```bash
   curl https://your-app.azurecontainerapps.io/read-file/test.txt
   ```

6. **Execute Analytics**
   ```bash
   curl https://your-app.azurecontainerapps.io/query
   ```

### REST Client Testing
Use the provided REST client file [`test-api.rest`](../test-api.rest) with Visual Studio Code REST Client extension.

## 🔗 Interactive Documentation

### Swagger UI
Access interactive API documentation:
```
https://your-app.azurecontainerapps.io/docs
```

### ReDoc
Alternative documentation interface:
```
https://your-app.azurecontainerapps.io/redoc
```

## 📊 Response Codes

### Success Codes
- `200 OK` - Request successful
- `201 Created` - Resource created successfully

### Error Codes
- `400 Bad Request` - Invalid request parameters
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

### Error Response Format
```json
{
  "error": "File not found",
  "detail": "The file 'nonexistent.txt' does not exist",
  "status_code": 404
}
```

## 🔍 Monitoring and Logging

### Application Logs
View real-time application logs:

```bash
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow
```

### Health Monitoring
The `/health` endpoint provides detailed system status:
- Storage accessibility
- Database connectivity
- System timestamp
- Application version

### Performance Metrics
- Response times logged for each endpoint
- Storage operation metrics
- Database query execution times

## 🔒 Security Considerations

### Authentication
- No authentication required for demo purposes
- For production, implement Azure AD integration:
  ```python
  from fastapi import Depends, HTTPException
  from azure.identity import DefaultAzureCredential
  ```

### Data Validation
- Input validation using Pydantic models
- File size limits enforced
- Filename sanitization

### CORS Configuration
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 🧪 Local Development

### Running Locally
```bash
# Using Docker Compose
docker-compose up --build

# Direct Python execution
cd app
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Local API Base URL
```
http://localhost:8000
```

### Local Testing
```bash
# Test local instance
./test-api.sh http://localhost:8000
```

## 🔄 API Versioning

### Current Version
- **Version**: 1.0.0
- **API Prefix**: None (direct endpoints)

### Future Versioning Strategy
```python
# Planned versioning approach
from fastapi import APIRouter

v1_router = APIRouter(prefix="/v1")
v2_router = APIRouter(prefix="/v2")
```

## 🔗 Related Documentation

- [Data Warehouse Guide](data-warehouse.md)
- [Azure Deployment](azure-deployment.md)
- [Docker & Containers](docker.md)
- [Troubleshooting](troubleshooting.md)

## 📝 Example Integration

### Python Client Example
```python
import requests
import json

base_url = "https://your-app.azurecontainerapps.io"

# Health check
response = requests.get(f"{base_url}/health")
print(response.json())

# Write file
data = {
    "content": "Hello from Python client",
    "filename": "python-test.txt"
}
response = requests.post(f"{base_url}/write-file", json=data)
print(response.json())

# Execute analytics
response = requests.get(f"{base_url}/query")
analytics_data = response.json()
print(f"Found {len(analytics_data['results'])} countries")
```

### JavaScript Client Example
```javascript
const baseUrl = 'https://your-app.azurecontainerapps.io';

// Health check
async function checkHealth() {
    const response = await fetch(`${baseUrl}/health`);
    const data = await response.json();
    console.log('Health:', data);
}

// Write file
async function writeFile(content, filename) {
    const response = await fetch(`${baseUrl}/write-file`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ content, filename })
    });
    return await response.json();
}
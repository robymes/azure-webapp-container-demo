# FastAPI Azure Container Apps Demo

A complete solution for deploying a FastAPI application to Azure Container Apps using Docker with persistent storage integration and data warehouse capabilities.

## 🏗️ Architecture Overview

- **Application**: FastAPI REST API with file operations and analytics
- **Containerization**: Docker with Azure Container Registry (ACR)
- **Hosting**: Azure Container Apps (serverless containers)
- **Storage**: Azure Storage File Share for persistence
- **Data Warehouse**: DuckDB integration with analytics capabilities
- **Automation**: Terraform for infrastructure as code

## 🚀 Quick Start

```bash
git clone <repository-url>
cd azure-webapp-container-demo
chmod +x azure-scripts/*.sh

# Complete deployment
cd azure-scripts
./full-deploy.sh latest
```

## 📁 Project Structure

```
├── app/                     # FastAPI application
├── azure-scripts/           # Terraform and deployment scripts
├── docs/                    # Detailed documentation
├── docker-compose.yml       # Local development
├── Dockerfile              # Container definition
└── test-api.sh             # API testing script
```

## 🔧 Key Features

- **REST API**: File operations, health checks, and analytics endpoints
- **Data Warehouse**: DuckDB integration with e-commerce analytics
- **Containerization**: Private Azure Container Registry
- **Persistent Storage**: Azure Files integration
- **Auto-scaling**: Azure Container Apps with demand-based scaling
- **Security**: Managed Identity authentication and Azure security policies

## 📚 Documentation

Detailed documentation is organized by topic in the [`docs/`](docs/) directory:

- **[🏗️ Terraform Infrastructure](docs/terraform.md)** - Infrastructure as code setup and configuration
- **[🔌 API Documentation](docs/api.md)** - FastAPI endpoints and usage examples
- **[📊 Data Warehouse](docs/data-warehouse.md)** - DuckDB integration and analytics
- **[🐳 Docker & Containers](docs/docker.md)** - Containerization and Azure Container Registry
- **[☁️ Azure Deployment](docs/azure-deployment.md)** - Azure services and deployment strategies
- **[🔒 Security & Configuration](docs/security.md)** - Azure security policies and configuration
- **[🐛 Troubleshooting](docs/troubleshooting.md)** - Common issues and maintenance

## 📋 Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/get-docker/) (for local testing)

## 🧪 Local Testing

```bash
# Build and run locally
docker-compose up --build

# Test endpoints
./test-api.sh
```

## 💰 Cost Estimation

Approximate monthly costs (West Europe):
- **Container Apps**: Pay-per-use (~€0.000024/vCPU-second)
- **Azure Container Registry**: ~€4.50/month
- **Storage Account**: ~€0.05/GB/month

**Total estimated**: ~€5-15/month depending on usage

## 🧹 Cleanup

```bash
cd azure-scripts
./terraform-cleanup.sh
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

1. Check the [troubleshooting guide](docs/troubleshooting.md)
2. Review topic-specific documentation in [`docs/`](docs/)
3. Open an issue in this repository
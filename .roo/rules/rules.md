# Software Development AI Agent Documentation

## Project Overview

This project aims to create a **Proof of Concept (PoC)** for an open-source data platform focused on achieving **operational efficiency** and **cost reduction**. The platform is designed to showcase how modern cloud-native and open-source technologies can be orchestrated to build scalable, maintainable, and cost-effective data solutions.

The PoC serves as a foundation to demonstrate key concepts and workflows, enabling future enhancements and expansions of the data platform based on practical usage and iterative improvements.

## Technologies Used

The project leverages a combination of cloud services, containerization, and modern data processing libraries to provide a robust foundation for the platform:

- **Azure Kubernetes Service (AKS):** Provides a managed Kubernetes environment in Azure for scalable container orchestration.
- **Azure Storage Account:** Used for persistent storage of data and container state required by the platform.
- **Azure Container Registry:** Used to host Docker images.
- **Docker:** Enables containerization of the application components for consistent development and deployment environments.
- **Python:** The primary programming language employed for backend logic and data integration.
- **FastAPI:** A modern, high-performance web framework for building APIs with Python, supporting asynchronous operations and easy scalability.
- **DuckDB + Ducklake:** Embedded analytical database (DuckDB) combined with Ducklake for managing data lakes efficiently and enabling fast, in-process analytical queries.

## Development Environment and Deployment

### Local Development

On the developer’s local machine, the project runs using **Docker Compose**, which orchestrates multiple containers to simulate the entire platform stack. This setup facilitates rapid development, local testing, and debugging without the need for cloud resources, allowing developers to iterate quickly.

### Cloud Deployment

For production and scalability, the platform runs on **Azure Kubernetes Service (AKS)**. Deployment to AKS is managed via **Terraform**, ensuring infrastructure as code principles are followed to maintain reproducibility, versioning, and automation.

- Terraform scripts provision the AKS cluster and associated Azure resources.
- Continuous upgrades to the environment are handled by Terraform, considering incremental environment changes rather than full teardowns.

## Proof of Concept (PoC) Objectives

The primary goal of the PoC is to **simplify the deployment process of an open-source data platform** by providing automated, modular, and repeatable infrastructure and application deployment workflows.

Key objectives include:

- Validate container-based deployment architectures.
- Demonstrate ease of deployment both locally and on cloud infrastructure.
- Provide a foundation for future enhancements and multiple interacting container components.

## Architectural Vision

The project is architected with an evolutionary, modular design:

- Initially, the platform starts with a **single container** encompassing core functionalities.
- Over time, additional containers can be incrementally added, representing services or features that interact with the core component.
- This modular expansion supports scalability, maintainability, and separation of concerns.

## Development Strategy

The development approach emphasizes **incremental consolidation and evolution**:

- Each stage or iteration delivers a fully functional and stable implementation of specific features.
- After stabilization, the next phase is planned and developed based on the current stable baseline.
- This iterative methodology ensures continuous improvement without compromising overall system integrity.

## Terraform Deployment Considerations

The deployment infrastructure as code strategy mandates a careful approach:

- The **initial release** provisions the entire environment from scratch in Azure, starting with a clean slate.
- Subsequent releases must assume an **existing environment state** and perform **incremental upgrades** rather than full reconstructions.
- This approach ensures minimal downtime, state preservation, and enables smooth environment evolution in production settings.
- Terraform configuration should be modular and capable of detecting current environment state to plan appropriate upgrade paths.
- PoC Azure environment should have the following charachteristics:
  - Subscription: already logged in with az CLI
  - Resource Group name: jkl-open-data-platform
  - Region: Italy North
  - Docker container data volume **MUST** be persistent using the Azure Storage Account
  - Virtual newtork should contain a VPN Gateway
  - Split pure Terraform infrastructure provisioning from Docker image registry push and AKS pod creation

## Azure Security Policies

The actual Azure environment is affected by some strict security policies that **MUST** be taken into account when implementing Terraform deployment, otherwise the deployment will fail:
- Azure Atorage Account must avoid public IP
- Azure Storage Account must avoid shared key access
- Accessing Azure Storage Account from other services must avoid shared access key
- Every other Azure service which need access to an Azure Storage Cccount must use private link and managed identities
- Temp disks and cache for agent node pools in Azure Kubernetes Service (AKS) clusters must be encrypted at host

These limitations are hard to manage: you must perform a web search and use the **microsoft-learn** MCP server in order to properly design and implement a successful deployment strategy with Terraform, especially when deciding in which sequential order Azure services must be created and/or updated.

# General best practices

- You must take care of project repository efficiency cleaning up all the resocurces not used anymore after a code rafactoring.
- Always keep documentaion up to date

# Azure security constraints

Strictly always ensure the following Azure security constraints:
- Azure Atorage Account must avoid public IP
- Azure Storage Account must avoid shared key access
- Accessing Azure Storage Account fromother services must avoid shared access key
- Every other Azure service which need access to an azure storage account must use private link and managed identities
- Temp disks and cache for agent node pools in Azure Kubernetes Service clusters must be encrypted at host

# MCP

Use sequentialthinking.
Use context7.
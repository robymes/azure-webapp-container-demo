# Azure Container Registry Deployment Guide

Questa guida spiega come utilizzare il nuovo Azure Container Registry (ACR) per deployare l'applicazione FastAPI su Azure App Service.

## 🏗️ Architettura

Il setup include:
- **Azure Container Registry (ACR)**: Registry privato per le immagini Docker
- **Azure App Service**: Hosting dell'applicazione web con Linux container
- **Managed Identity**: Autenticazione sicura tra App Service e ACR
- **Azure Storage**: Storage persistente per i file dell'applicazione

## 📋 Prerequisiti

- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Docker installato e in esecuzione
- Permessi di Contributor su Azure Subscription

## 🚀 Deployment Automatico (Opzione Raccomandata)

Per deployare tutto con un singolo comando:

```bash
cd azure-scripts
./full-deploy.sh [tag]
```

Esempio:
```bash
# Deploy con tag latest
./full-deploy.sh

# Deploy con tag specifico
./full-deploy.sh v1.2.3
```

Questo script eseguirà automaticamente:
1. Deploy dell'infrastruttura con Terraform
2. Build dell'immagine Docker
3. Push dell'immagine su ACR
4. Restart del Web App per applicare la nuova immagine

## 🔧 Deployment Manuale (Step by Step)

### Step 1: Deploy dell'Infrastruttura

```bash
cd azure-scripts
terraform init
terraform plan
terraform apply
```

### Step 2: Build e Push dell'Immagine Docker

```bash
# Build e push con tag latest
./docker-build-push.sh

# Build e push con tag specifico
./docker-build-push.sh v1.0.0

# Specificare path del Dockerfile diverso
./docker-build-push.sh latest /custom/docker/path/
```

### Step 3: Restart del Web App (Opzionale)

```bash
# Ottieni i dettagli dal Terraform output
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
WEB_APP_NAME=$(terraform output -raw web_app_name)

# Restart dell'app
az webapp restart --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP
```

## 📊 Verifica del Deploy

### Check dello stato delle risorse

```bash
# Verifica ACR
terraform output container_registry_name
az acr repository list --name $(terraform output -raw container_registry_name)

# Verifica Web App
terraform output web_app_url
curl $(terraform output -raw web_app_url)/health
```

### Log del container

```bash
WEB_APP_NAME=$(terraform output -raw web_app_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)

# Log in tempo reale
az webapp log tail --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP
```

## 🔄 Aggiornamenti dell'Applicazione

Per aggiornare l'applicazione dopo modifiche al codice:

```bash
# Opzione 1: Full redeploy (raccomandato)
./full-deploy.sh v1.1.0

# Opzione 2: Solo build e push della nuova immagine
./docker-build-push.sh v1.1.0
az webapp restart --name $(terraform output -raw web_app_name) --resource-group $(terraform output -raw resource_group_name)
```

## 🏷️ Gestione dei Tag delle Immagini

### Strategie di Tagging

- **latest**: Versione più recente (default)
- **v1.0.0**: Versioning semantico
- **feature-xyz**: Branch di sviluppo
- **commit-abc123**: Commit specifico

### Lista delle immagini disponibili

```bash
ACR_NAME=$(terraform output -raw container_registry_name)
az acr repository show-tags --name $ACR_NAME --repository fastapi-app
```

## 🔐 Sicurezza

- **Managed Identity**: Il Web App usa l'identità gestita per accedere all'ACR
- **HTTPS Only**: Tutto il traffico è forzato su HTTPS
- **Private Registry**: ACR è privato e accessibile solo alle risorse autorizzate
- **Role-based Access**: Permessi minimali con ruolo AcrPull

## 🛠️ Troubleshooting

### L'immagine non viene pullata

```bash
# Verifica i permessi
az role assignment list --assignee $(terraform output -raw web_app_principal_id) --scope $(terraform output -raw container_registry_id)

# Forza il pull dell'immagine
az webapp restart --name $(terraform output -raw web_app_name) --resource-group $(terraform output -raw resource_group_name)
```

### Problemi di build Docker

```bash
# Build locale per test
docker build -t fastapi-app:test ..
docker run -p 8000:8000 fastapi-app:test

# Check dei log di build
./docker-build-push.sh 2>&1 | tee build.log
```

### Web App non risponde

```bash
# Check dello stato
az webapp show --name $(terraform output -raw web_app_name) --resource-group $(terraform output -raw resource_group_name) --query "state"

# Log dettagliati
az webapp log tail --name $(terraform output -raw web_app_name) --resource-group $(terraform output -raw resource_group_name)
```

## 🧹 Cleanup

Per rimuovere tutte le risorse create:

```bash
cd azure-scripts
terraform destroy
# oppure
./terraform-cleanup.sh
```

## 📝 Note Importanti

1. **Costi**: ACR Basic costa circa €4.50/mese + traffico
2. **Limiti**: ACR Basic supporta 10GB di storage
3. **Backup**: Le immagini Docker sono persistenti nell'ACR
4. **Scaling**: L'App Service Plan può essere scalato in base alle necessità
5. **Monitoring**: I log dell'applicazione sono disponibili via Azure CLI o Azure Portal

## 🔗 Output Utili

Dopo il deploy, usa questi comandi per ottenere le informazioni principali:

```bash
# URL dell'applicazione
terraform output web_app_url

# Dettagli del registry
terraform output container_registry_login_server

# Info complete
terraform output deployment_info
```

## 🚀 Esempi di Workflow

### Primo Deploy
```bash
# Clone del repository
git clone <your-repo>
cd azure-webapp-container-demo

# Login ad Azure
az login

# Deploy completo
cd azure-scripts
./full-deploy.sh v1.0.0
```

### Aggiornamento Applicazione
```bash
# Modifica il codice dell'applicazione
# Commit delle modifiche
git add .
git commit -m "New features"

# Build e deploy della nuova versione
./full-deploy.sh v1.1.0
```

### Deploy di un branch di sviluppo
```bash
# Switch al branch
git checkout feature/new-api

# Deploy con tag specifico
./full-deploy.sh feature-new-api

# Test dell'applicazione
curl $(terraform output -raw web_app_url)/health
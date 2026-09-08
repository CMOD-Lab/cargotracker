# Deployment Guide — cargo-tracker on Azure AKS

## Overview

This guide covers building, pushing, and deploying the **Eclipse Cargo Tracker** application (Jakarta EE 10, Java 11, Payara Micro) to **Azure Kubernetes Service (AKS)**.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Local Development with Docker Compose](#local-development-with-docker-compose)
4. [Build and Push Docker Image](#build-and-push-docker-image)
5. [Azure AKS Deployment](#azure-aks-deployment)
6. [Kubernetes Manifest Descriptions](#kubernetes-manifest-descriptions)
7. [Configuration Management](#configuration-management)
8. [Scaling and Management](#scaling-and-management)
9. [Troubleshooting](#troubleshooting)
10. [Security Considerations](#security-considerations)
11. [Technology-Specific Notes](#technology-specific-notes)

---

## Prerequisites

### Local Development
- Docker Desktop 24.x or later
- Docker Compose v2.x or later
- Java 11 JDK (Amazon Corretto 11 recommended)
- Apache Maven 3.9.x

### Azure AKS Deployment
- Azure CLI (`az`) 2.50+
- `kubectl` 1.27+
- An active Azure subscription
- Azure Container Registry (ACR) or Docker Hub account
- AKS cluster with Application Gateway Ingress Controller (AGIC) enabled

### Install Azure CLI
```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Windows
winget install Microsoft.AzureCLI
```

### Install kubectl
```bash
az aks install-cli
```

---

## Project Structure

```
BackendServices/
├── Dockerfile                    # Multi-stage build (Maven builder + Amazon Corretto 11 runtime)
├── .dockerignore                 # Excludes target/, wrapper scripts, test files
├── docker-compose.yml            # Local development (application only)
├── pom.xml                       # Maven build descriptor (Java 11, Jakarta EE 10, WAR packaging)
├── post-boot-commands.asadmin    # Payara Micro post-boot configuration
├── src/
│   └── main/
│       ├── java/                 # Application source code
│       ├── webapp/               # JSF/Faces web resources
│       ├── resources/            # Persistence, batch job configs
│       └── liberty/config/       # OpenLiberty server config (alternative)
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment (2 replicas)
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # Azure Application Gateway ingress
├── scripts/
│   ├── build-push.sh             # Linux/macOS: build and push Docker image
│   ├── build-push.bat            # Windows: build and push Docker image
│   ├── deploy-image.sh           # Linux/macOS: deploy to AKS
│   └── deploy-image.bat          # Windows: deploy to AKS
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development with Docker Compose

### 1. Configure Environment Variables

Create a `.env` file in the project root:

```env
DB_JDBC_URL=jdbc:postgresql://host.docker.internal:5432/cargotracker
DB_USER=postgres
DB_PASSWORD=yourpassword
GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
```

> **Note**: The application requires a PostgreSQL database. Ensure PostgreSQL is running and accessible before starting the application container.

### 2. Start the Application

```bash
docker-compose up --build
```

### 3. Access the Application

- **Application UI**: http://localhost:8080/cargo-tracker
- **Health Check**: http://localhost:8080/cargo-tracker/rest/health
- **REST API**: http://localhost:8080/cargo-tracker/rest/

### 4. Stop the Application

```bash
docker-compose down
```

---

## Build and Push Docker Image

### Linux / macOS

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type: **Azure ACR** or **Docker Hub**
3. Provide registry credentials

### Windows

```cmd
scripts\build-push.bat
```

### Manual Build

```bash
# Build image
docker build -t cargo-tracker:latest .

# Tag for ACR
docker tag cargo-tracker:latest <acr-name>.azurecr.io/cargo-tracker:latest

# Login to ACR
az acr login --name <acr-name>

# Push
docker push <acr-name>.azurecr.io/cargo-tracker:latest
```

---

## Azure AKS Deployment

### Step 1: Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### Step 2: Create AKS Cluster (if not existing)

```bash
# Create resource group
az group create --name cargo-tracker-rg --location eastus

# Create AKS cluster with AGIC enabled
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --enable-addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --generate-ssh-keys
```

### Step 3: Attach ACR to AKS

```bash
az aks update \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --attach-acr <acr-name>
```

### Step 4: Run Deployment Script

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- Azure Resource Group
- AKS Cluster name
- Full Docker image URI (e.g., `myregistry.azurecr.io/cargo-tracker:latest`)
- Database connection details (DB_JDBC_URL, DB_USER, DB_PASSWORD)
- Graph traversal URL

### Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -n cargo-tracker

# Check services
kubectl get svc -n cargo-tracker

# Check ingress
kubectl get ingress -n cargo-tracker

# View logs
kubectl logs -f deployment/cargo-tracker -n cargo-tracker
```

---

## Kubernetes Manifest Descriptions

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: Pulled from the registry specified during deployment
- **Resources**: 250m CPU / 512Mi memory (requests); 500m CPU / 1Gi memory (limits)
- **Liveness Probe**: HTTP GET `/cargo-tracker/rest/health` on port 8080 (initial delay: 90s)
- **Readiness Probe**: HTTP GET `/cargo-tracker/rest/health` on port 8080 (initial delay: 60s)
- **Environment Variables**: DB_JDBC_URL, DB_USER, DB_PASSWORD, GRAPH_TRAVERSAL_URL, JAVA_OPTS

### service.yaml
- **Type**: ClusterIP (internal access only)
- **Port**: 80 → 8080 (container port)

### ingress.yaml
- **Class**: `azure/application-gateway` (AGIC)
- **Host**: `cargo-tracker.example.com` (update to your actual domain)
- **Path**: `/` (all traffic routed to the application)

> **Update the ingress host**: Edit `kubernetes/ingress.yaml` and replace `cargo-tracker.example.com` with your actual domain name.

---

## Configuration Management

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DB_JDBC_URL` | PostgreSQL JDBC connection URL | `jdbc:postgresql://localhost:5432/cargotracker` |
| `DB_USER` | Database username | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `GRAPH_TRAVERSAL_URL` | Internal graph traversal REST endpoint | `http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0` |
| `TZ` | Timezone | `UTC` |

### Using Kubernetes Secrets (Recommended for Production)

```bash
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=DB_JDBC_URL="jdbc:postgresql://your-db-host:5432/cargotracker" \
  --from-literal=DB_USER="your-db-user" \
  --from-literal=DB_PASSWORD="your-db-password" \
  -n cargo-tracker
```

Then reference in `deployment.yaml`:
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: cargo-tracker-db-secret
        key: DB_PASSWORD
```

---

## Scaling and Management

### Manual Scaling

```bash
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker
```

### Horizontal Pod Autoscaler (HPA)

```bash
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=5 \
  -n cargo-tracker
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=<new-image-uri> \
  -n cargo-tracker

# Monitor rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

### Rollback

```bash
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# Rollback to specific revision
kubectl rollout undo deployment/cargo-tracker --to-revision=2 -n cargo-tracker
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod -l app=cargo-tracker -n cargo-tracker

# Check logs
kubectl logs -l app=cargo-tracker -n cargo-tracker --previous
```

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| `ImagePullBackOff` | Cannot pull image from registry | Verify ACR attachment: `az aks update --attach-acr <acr-name>` |
| `CrashLoopBackOff` | Application startup failure | Check logs; verify DB_JDBC_URL is reachable from AKS |
| `Pending` pods | Insufficient cluster resources | Scale up node pool or reduce resource requests |
| Health probe failures | Slow JVM startup | Increase `initialDelaySeconds` in deployment.yaml |
| Database connection refused | DB not accessible from AKS | Verify VNet peering or use Azure Database for PostgreSQL |

### Check Ingress

```bash
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker
kubectl get events -n cargo-tracker --sort-by='.lastTimestamp'
```

### Port-Forward for Local Testing

```bash
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
# Access at: http://localhost:8080/cargo-tracker
```

---

## Security Considerations

1. **Non-root container**: The Dockerfile creates and uses a `payara` non-root user.
2. **Secrets management**: Use Kubernetes Secrets or Azure Key Vault CSI driver for sensitive values.
3. **Network policies**: Consider adding Kubernetes NetworkPolicy to restrict pod-to-pod communication.
4. **Image scanning**: Enable ACR vulnerability scanning: `az acr task create --name scan ...`
5. **RBAC**: Apply least-privilege RBAC roles for the application service account.
6. **TLS**: Configure TLS termination at the Application Gateway level for HTTPS.

---

## Technology-Specific Notes

### Jakarta EE 10 / Payara Micro

- The application is packaged as a **WAR** file and deployed on **Payara Micro 6.2025.3**.
- Payara Micro is embedded in the Docker image and started via `java -jar payara-micro.jar`.
- The application context root is `/cargo-tracker`.
- JMS queues (CargoHandledQueue, MisdirectedCargoQueue, etc.) are managed internally by Payara Micro.

### Java 11 JVM Tuning

The following JVM flags are set via `JAVA_OPTS`:
- `-Xmx512m -Xms256m`: Heap size bounds
- `-XX:+UseContainerSupport`: Enables container-aware memory management
- `-XX:MaxRAMPercentage=75.0`: Limits heap to 75% of container memory
- `-XX:+UnlockExperimentalVMOptions`: Enables experimental JVM features

### Database

- **Default (local/dev)**: H2 in-file mode (embedded, no external DB needed)
- **Cloud/Production**: PostgreSQL via the `cloud` Maven profile
- The `cloud` Maven profile is used during Docker build to include the PostgreSQL JDBC driver

### Health Check Endpoint

The application exposes a custom health endpoint at:
```
GET /cargo-tracker/rest/health
Response: {"status":"UP","application":"cargo-tracker"}
```

This endpoint is used by both Kubernetes liveness and readiness probes.

# Cargo Tracker – Deployment Guide (Azure AKS)

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Analysis](#project-analysis)
4. [Local Development with Docker Compose](#local-development-with-docker-compose)
5. [Build & Push Docker Image](#build--push-docker-image)
6. [Azure AKS Deployment](#azure-aks-deployment)
7. [Kubernetes Manifest Reference](#kubernetes-manifest-reference)
8. [Configuration & Environment Variables](#configuration--environment-variables)
9. [Scaling & Management](#scaling--management)
10. [Troubleshooting](#troubleshooting)
11. [Security Considerations](#security-considerations)

---

## Overview

**Eclipse Cargo Tracker** is a Jakarta EE 10 reference application demonstrating Domain-Driven Design (DDD) patterns. It is packaged as a WAR file and deployed on **Payara Micro** (Jakarta EE application server).

| Property | Value |
|---|---|
| Application Name | cargo-tracker |
| Java Version | 11 |
| Build Tool | Maven 3.9.x |
| Package Type | WAR |
| Application Server | Payara Micro 6.2025.3 |
| Application Port | 8080 |
| Base Runtime Image | amazoncorretto:11 |
| Target Platform | Azure AKS |

---

## Prerequisites

### Local Development
- **Docker** 24.x or later
- **Docker Compose** v2.x or later
- **Java 11** (for local builds outside Docker)
- **Maven 3.9.x** (for local builds outside Docker)

### Azure AKS Deployment
- **Azure CLI** (`az`) 2.50+  
  Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- **kubectl** 1.27+  
  Install: `az aks install-cli`
- **Azure Subscription** with permissions to:
  - Create/manage AKS clusters
  - Push to Azure Container Registry (ACR)
- **Azure Container Registry (ACR)** or Docker Hub account

---

## Project Analysis

### Technology Stack
- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF, JMS, Batch)
- **UI**: Jakarta Faces (JSF) with PrimeFaces 14
- **Persistence**: JPA (EclipseLink) with H2 (default) or PostgreSQL (cloud profile)
- **Messaging**: JMS queues (built-in Payara Micro)
- **REST**: JAX-RS (Jersey)

### Maven Profiles
| Profile | Database | Use Case |
|---|---|---|
| `payara` (default) | H2 embedded | Local development |
| `glassfish` | H2 embedded | GlassFish testing |
| `cloud` | PostgreSQL | Production/cloud |
| `openliberty` | HSQLDB | OpenLiberty testing |

---

## Local Development with Docker Compose

### Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd "Trianz digital"

# Start the application
docker compose up --build

# Access the application
open http://localhost:8080/cargo-tracker
```

### Stop the Application

```bash
docker compose down

# Remove volumes (clears database)
docker compose down -v
```

### Environment Variables for Docker Compose

Create a `.env` file in the project root to override defaults:

```env
DB_JDBC_URL=jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database
DB_USER=
DB_PASSWORD=
GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
```

For PostgreSQL (cloud profile), update:

```env
DB_JDBC_URL=jdbc:postgresql://your-postgres-host:5432/cargotracker
DB_USER=postgres
DB_PASSWORD=your-password
```

---

## Build & Push Docker Image

### Linux / macOS

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run from repository root
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type (ACR or Docker Hub)
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

### Step 1: Set Up Azure Resources

```bash
# Login to Azure
az login

# Create resource group (if needed)
az group create --name cargo-tracker-rg --location eastus

# Create ACR (if needed)
az acr create --resource-group cargo-tracker-rg \
              --name cargotrackercr \
              --sku Basic

# Create AKS cluster (if needed)
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --enable-addons monitoring \
  --attach-acr cargotrackercr \
  --generate-ssh-keys
```

### Step 2: Build and Push Image

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
# Select ACR, enter: cargotrackercr
# Enter tag: v3.1
```

### Step 3: Deploy to AKS

#### Linux / macOS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

#### Windows

```cmd
scripts\deploy-image.bat
```

The deploy script will prompt for:
- Azure Resource Group
- AKS Cluster name
- Full Docker image URI (e.g., `cargotrackercr.azurecr.io/cargo-tracker:v3.1`)
- Database connection details (optional, defaults to H2 embedded)

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n cargo-tracker

# Check services
kubectl get svc -n cargo-tracker

# Check ingress
kubectl get ingress -n cargo-tracker

# View logs
kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=100
```

### Step 5: Access the Application

```bash
# Get ingress IP
kubectl get ingress cargo-tracker-ingress -n cargo-tracker

# Port-forward for quick access (no ingress required)
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
# Then open: http://localhost:8080/cargo-tracker
```

---

## Kubernetes Manifest Reference

### Files Generated

| File | Description |
|---|---|
| `kubernetes/namespace.yaml` | Namespace: `cargo-tracker` |
| `kubernetes/deployment.yaml` | Deployment with 2 replicas, resource limits, health probes |
| `kubernetes/service.yaml` | ClusterIP service on port 80 → 8080 |
| `kubernetes/ingress.yaml` | Azure Application Gateway Ingress |

### Deployment Placeholders

The `deployment.yaml` uses these placeholders replaced by `deploy-image.sh`:

| Placeholder | Description |
|---|---|
| `{{IMAGE_URI}}` | Full Docker image URI with tag |
| `{{DB_JDBC_URL}}` | JDBC connection URL |
| `{{DB_USER}}` | Database username |
| `{{DB_PASSWORD}}` | Database password |
| `{{GRAPH_TRAVERSAL_URL}}` | Graph traversal REST endpoint URL |

### Resource Limits

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "500m"
    memory: "1Gi"
```

> **Note**: Payara Micro with Jakarta EE requires at least 512Mi memory. Increase limits for production workloads.

---

## Configuration & Environment Variables

| Variable | Default | Description |
|---|---|---|
| `JAVA_OPTS` | `-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0` | JVM options |
| `TZ` | `UTC` | Timezone |
| `DB_JDBC_URL` | `jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database` | JDBC URL |
| `DB_USER` | _(empty)_ | Database username |
| `DB_PASSWORD` | _(empty)_ | Database password |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path` | Graph traversal service URL |

### Using PostgreSQL in Production

1. Provision a PostgreSQL instance (Azure Database for PostgreSQL recommended)
2. Set environment variables:
   ```
   DB_JDBC_URL=jdbc:postgresql://<host>:5432/<database>
   DB_USER=<username>
   DB_PASSWORD=<password>
   ```
3. Build with the cloud profile:
   ```bash
   mvn clean package -Pcloud \
     -DpostgreSqlJdbcUrl="jdbc:postgresql://host:5432/db" \
     -DpostgreSqlUsername="user" \
     -DpostgreSqlPassword="pass"
   ```

---

## Scaling & Management

### Manual Scaling

```bash
# Scale to 3 replicas
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker
```

### Horizontal Pod Autoscaler (HPA)

```bash
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker

# Check HPA status
kubectl get hpa -n cargo-tracker
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
# Rollback to previous version
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# Rollback to specific revision
kubectl rollout history deployment/cargo-tracker -n cargo-tracker
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

**Common causes:**
- Insufficient memory: Increase `resources.limits.memory` to `2Gi`
- Image pull error: Verify ACR credentials and image URI
- Payara startup timeout: Increase `initialDelaySeconds` in health probes

### Application Not Accessible

```bash
# Check service endpoints
kubectl get endpoints cargo-tracker-service -n cargo-tracker

# Check ingress
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Port-forward to bypass ingress
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
```

### Database Connection Issues

```bash
# Check environment variables in pod
kubectl exec -it <pod-name> -n cargo-tracker -- env | grep DB_

# For H2 embedded, verify volume mount
kubectl describe pod <pod-name> -n cargo-tracker
```

### JVM Memory Issues

```bash
# Check memory usage
kubectl top pods -n cargo-tracker

# Increase JVM heap in deployment.yaml
# Change JAVA_OPTS: -Xms512m -Xmx768m
```

### Slow Startup

Payara Micro with Jakarta EE can take 60-90 seconds to start. The health probes are configured with:
- `initialDelaySeconds: 90` (liveness)
- `initialDelaySeconds: 60` (readiness)

If pods are being killed before startup completes, increase these values.

---

## Security Considerations

1. **Non-root container**: The Dockerfile creates a `payara` user and runs the application as non-root.

2. **Secrets management**: Use Kubernetes Secrets for database credentials:
   ```bash
   kubectl create secret generic cargo-tracker-db-secret \
     --from-literal=DB_USER=myuser \
     --from-literal=DB_PASSWORD=mypassword \
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

3. **Network policies**: Restrict pod-to-pod communication using Kubernetes NetworkPolicy.

4. **Image scanning**: Enable ACR vulnerability scanning:
   ```bash
   az acr task create --registry <acr-name> --name scan-on-push \
     --image cargo-tracker:{{.Run.ID}} --context /dev/null \
     --file /dev/null --commit-trigger-enabled false
   ```

5. **TLS/HTTPS**: Configure TLS on the ingress using Azure Application Gateway with a certificate from Azure Key Vault.

6. **Resource quotas**: Apply namespace resource quotas to prevent resource exhaustion:
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: cargo-tracker-quota
     namespace: cargo-tracker
   spec:
     hard:
       requests.cpu: "1"
       requests.memory: 2Gi
       limits.cpu: "2"
       limits.memory: 4Gi
   ```

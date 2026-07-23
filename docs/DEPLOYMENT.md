# Eclipse Cargo Tracker - Deployment Guide

## Azure Kubernetes Service (AKS) Deployment

**Application**: Eclipse Cargo Tracker  
**Version**: 3.1-SNAPSHOT  
**Framework**: Jakarta EE 10 (Payara Server)  
**Java Version**: 11  
**Package Type**: WAR  
**Application Port**: 8080  
**Health Endpoint**: `/cargo-tracker/rest/health`

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Overview](#project-overview)
3. [Local Development with Docker Compose](#local-development-with-docker-compose)
4. [Build and Push Docker Image](#build-and-push-docker-image)
5. [Azure AKS Prerequisites](#azure-aks-prerequisites)
6. [AKS Cluster Setup](#aks-cluster-setup)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Configuration Management](#configuration-management)
9. [Monitoring and Health Checks](#monitoring-and-health-checks)
10. [Scaling and Management](#scaling-and-management)
11. [Troubleshooting](#troubleshooting)
12. [Security Considerations](#security-considerations)
13. [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### Local Development Tools
- **Docker Desktop** 24.x or later — [Install](https://docs.docker.com/get-docker/)
- **Java 11** (Amazon Corretto 11 or Eclipse Temurin 11) — [Install](https://adoptium.net/)
- **Apache Maven 3.9.x** — [Install](https://maven.apache.org/download.cgi)

### Azure AKS Deployment Tools
- **Azure CLI** 2.50+ — [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **kubectl** 1.27+ — [Install](https://kubernetes.io/docs/tasks/tools/)
- **Azure Subscription** with permissions to create AKS clusters and ACR registries
- **Azure Container Registry (ACR)** or Docker Hub account

---

## Project Overview

Eclipse Cargo Tracker is a Jakarta EE 10 reference application demonstrating Domain-Driven Design (DDD) patterns. It runs on **Payara Server 6.x** and uses:

- **Jakarta EE 10** (CDI, JPA, JAX-RS, JSF, JMS, Batch)
- **H2 Database** (embedded, for development/default profile)
- **PostgreSQL** (for cloud/production profile via `-Pcloud`)
- **PrimeFaces 14** for UI
- **JMS Queues** for asynchronous messaging (built-in Payara messaging)

The application is packaged as a **WAR** file (`cargo-tracker.war`) and deployed to Payara Server.

---

## Local Development with Docker Compose

### Step 1: Build and Start

```bash
# From project root
docker-compose up --build
```

### Step 2: Access the Application

- **Application**: http://localhost:8080/cargo-tracker
- **Payara Admin Console**: http://localhost:4848
- **Health Check**: http://localhost:8080/cargo-tracker/rest/health

### Step 3: Stop the Application

```bash
docker-compose down
```

### Step 4: View Logs

```bash
docker-compose logs -f cargo-tracker
```

### Environment Variables (docker-compose.yml)

| Variable | Default | Description |
|---|---|---|
| `TZ` | `UTC` | Timezone |
| `APP_SERVER` | `payara` | Application server identifier |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path` | Graph traversal service URL |
| `DB_DRIVER_CLASS` | `org.h2.jdbcx.JdbcDataSource` | JDBC driver class |
| `DB_JDBC_URL` | `jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database` | JDBC connection URL |
| `DB_USER` | _(empty)_ | Database username |
| `DB_PASSWORD` | _(empty)_ | Database password |

---

## Build and Push Docker Image

### Linux/macOS

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

### Windows

```cmd
scripts\build-push.bat
```

### Script Prompts

1. **Image tag** — e.g., `v3.1`, `latest`
2. **Registry type** — `1` for Azure ACR, `2` for Docker Hub
3. **Registry credentials** — ACR name or Docker Hub username/password

### Manual Build (Advanced)

```bash
# Build image
docker build -t myregistry.azurecr.io/cargo-tracker:latest .

# Login to ACR
az acr login --name myregistry

# Push image
docker push myregistry.azurecr.io/cargo-tracker:latest
```

---

## Azure AKS Prerequisites

### 1. Install Azure CLI and Login

```bash
# Install Azure CLI (Linux)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Set subscription
az account set --subscription "<your-subscription-id>"
```

### 2. Install kubectl

```bash
# Via Azure CLI
az aks install-cli

# Or via package manager
# macOS: brew install kubectl
# Linux: snap install kubectl --classic
```

### 3. Create Azure Container Registry (ACR)

```bash
# Create resource group
az group create --name cargo-tracker-rg --location eastus

# Create ACR
az acr create \
  --resource-group cargo-tracker-rg \
  --name cargotrackercr \
  --sku Basic

# Login to ACR
az acr login --name cargotrackercr
```

---

## AKS Cluster Setup

### 1. Create AKS Cluster

```bash
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-addons monitoring \
  --attach-acr cargotrackercr \
  --generate-ssh-keys
```

### 2. Configure kubectl

```bash
az aks get-credentials \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks
```

### 3. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

### 4. Install Application Gateway Ingress Controller (AGIC)

```bash
# Enable AGIC add-on
az aks enable-addons \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16"
```

---

## Kubernetes Deployment

### Automated Deployment (Recommended)

#### Linux/macOS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

#### Windows

```cmd
scripts\deploy-image.bat
```

The script will prompt for:
- Azure Resource Group name
- AKS Cluster name
- Docker image URI (full path with tag)
- Optional environment variable values

### Manual Deployment

#### Step 1: Update deployment.yaml

Edit `kubernetes/deployment.yaml` and replace placeholders:
- `{{IMAGE_URI}}` → your full image URI (e.g., `cargotrackercr.azurecr.io/cargo-tracker:latest`)
- `{{GRAPH_TRAVERSAL_URL}}` → graph traversal service URL
- `{{DB_DRIVER_CLASS}}` → JDBC driver class
- `{{DB_JDBC_URL}}` → JDBC connection URL

#### Step 2: Apply Manifests

```bash
# Apply in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
```

#### Step 3: Verify Deployment

```bash
# Check pods
kubectl get pods -n cargo-tracker

# Check all resources
kubectl get pods,svc,ingress -n cargo-tracker

# Watch rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

#### Step 4: Access the Application

```bash
# Get ingress IP
kubectl get ingress cargo-tracker-ingress -n cargo-tracker

# Port-forward for local testing
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
# Then access: http://localhost:8080/cargo-tracker
```

### Kubernetes Manifest Descriptions

| File | Description |
|---|---|
| `kubernetes/namespace.yaml` | Creates `cargo-tracker` namespace |
| `kubernetes/deployment.yaml` | Deploys 2 replicas of cargo-tracker with health probes |
| `kubernetes/service.yaml` | ClusterIP service exposing port 80 → 8080 |
| `kubernetes/ingress.yaml` | Azure Application Gateway Ingress with host routing |

---

## Configuration Management

### Database Configuration

For **production** with PostgreSQL, create a Kubernetes Secret:

```bash
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=db-user=postgres \
  --from-literal=db-password=your-secure-password \
  -n cargo-tracker
```

Update `deployment.yaml` environment variables:
```yaml
- name: DB_DRIVER_CLASS
  value: "org.postgresql.ds.PGPoolingDataSource"
- name: DB_JDBC_URL
  value: "jdbc:postgresql://your-postgres-host:5432/cargotracker"
```

### JVM Configuration

The `JAVA_TOOL_OPTIONS` environment variable controls JVM settings:

```yaml
- name: JAVA_TOOL_OPTIONS
  value: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Xms256m -Xmx512m -Dfile.encoding=UTF-8"
```

Adjust `-Xmx` based on your container memory limits. With `1Gi` limit, `-Xmx768m` is recommended.

### Graph Traversal URL

For multi-pod deployments, set `GRAPH_TRAVERSAL_URL` to the internal service URL:

```yaml
- name: GRAPH_TRAVERSAL_URL
  value: "http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path"
```

---

## Monitoring and Health Checks

### Health Endpoint

The application exposes a custom health endpoint:

```
GET /cargo-tracker/rest/health
```

**Response (200 OK)**:
```json
{
  "status": "UP",
  "application": "cargo-tracker",
  "version": "3.1-SNAPSHOT"
}
```

### Kubernetes Probes

The deployment is configured with:

| Probe | Path | Initial Delay | Period |
|---|---|---|---|
| **Liveness** | `/cargo-tracker/rest/health` | 120s | 30s |
| **Readiness** | `/cargo-tracker/rest/health` | 60s | 15s |

> **Note**: Payara Server requires significant startup time (60-120 seconds). The initial delays are set accordingly.

### View Logs

```bash
# All pods
kubectl logs -l app=cargo-tracker -n cargo-tracker -f

# Specific pod
kubectl logs <pod-name> -n cargo-tracker -f

# Previous container (if crashed)
kubectl logs <pod-name> -n cargo-tracker --previous
```

---

## Scaling and Management

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
  --max=5 \
  -n cargo-tracker
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=cargotrackercr.azurecr.io/cargo-tracker:v3.2 \
  -n cargo-tracker

# Monitor rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

### Resource Limits

Current configuration:

| Resource | Request | Limit |
|---|---|---|
| CPU | 250m | 500m |
| Memory | 512Mi | 1Gi |

Adjust in `kubernetes/deployment.yaml` based on load testing results.

---

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n cargo-tracker

# Check logs
kubectl logs <pod-name> -n cargo-tracker --tail=100
```

**Common Issues**:
- **ImagePullBackOff**: Check ACR credentials and image URI
- **CrashLoopBackOff**: Check application logs for startup errors
- **OOMKilled**: Increase memory limits or JVM heap settings

### Payara Startup Issues

Payara Server takes 60-120 seconds to start. If pods are failing health checks:

```bash
# Temporarily increase initial delay
kubectl patch deployment cargo-tracker -n cargo-tracker \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"cargo-tracker","livenessProbe":{"initialDelaySeconds":180}}]}}}}'
```

### Database Connection Issues

```bash
# Check environment variables in pod
kubectl exec -it <pod-name> -n cargo-tracker -- env | grep DB_

# Test connectivity (if psql available)
kubectl exec -it <pod-name> -n cargo-tracker -- sh
```

### Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Check AGIC logs
kubectl logs -l app=ingress-appgw -n kube-system -f
```

### Service Discovery Issues

```bash
# Check service endpoints
kubectl get endpoints cargo-tracker-service -n cargo-tracker

# Test internal connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://cargo-tracker-service.cargo-tracker.svc.cluster.local/cargo-tracker/rest/health
```

---

## Security Considerations

1. **Non-root Container**: The application runs as a non-root user (`payara`, UID 1000)
2. **Secrets Management**: Use Kubernetes Secrets or Azure Key Vault for database credentials
3. **Network Policies**: Consider adding Kubernetes NetworkPolicies to restrict pod-to-pod communication
4. **Image Scanning**: Enable ACR vulnerability scanning for the container image
5. **RBAC**: Apply least-privilege RBAC policies for the service account
6. **TLS**: Configure TLS termination at the Application Gateway level
7. **Pod Security**: The deployment includes `runAsNonRoot: true` and `runAsUser: 1000`

### Azure Key Vault Integration (Recommended for Production)

```bash
# Enable Azure Key Vault CSI driver
az aks enable-addons \
  --addons azure-keyvault-secrets-provider \
  --name cargo-tracker-aks \
  --resource-group cargo-tracker-rg
```

---

## Rollback Procedures

### Rollback Deployment

```bash
# Rollback to previous version
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# Rollback to specific revision
kubectl rollout history deployment/cargo-tracker -n cargo-tracker
kubectl rollout undo deployment/cargo-tracker --to-revision=2 -n cargo-tracker
```

### Delete All Resources

```bash
# Delete all resources in namespace
kubectl delete namespace cargo-tracker

# Or delete individual resources
kubectl delete -f kubernetes/ingress.yaml
kubectl delete -f kubernetes/service.yaml
kubectl delete -f kubernetes/deployment.yaml
kubectl delete -f kubernetes/namespace.yaml
```

---

## Technology-Specific Notes

### Jakarta EE 10 on Payara 6

- Payara Server 6.x is the reference implementation for Jakarta EE 10
- The application uses CDI 4.0, JPA 3.1, JAX-RS 3.1, JSF 4.0, JMS 3.1
- JMS queues are configured internally within Payara (no external broker needed)
- H2 database is embedded for development; PostgreSQL is recommended for production

### Maven Build Profiles

| Profile | Database | Use Case |
|---|---|---|
| `payara` (default) | H2 (file) | Local development |
| `glassfish` | H2 (file) | GlassFish testing |
| `cloud` | PostgreSQL | Production/AKS |
| `openliberty` | HSQLDB | OpenLiberty testing |

For production AKS deployment with PostgreSQL:
```bash
mvn clean package -Pcloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://host:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="password"
```

### JVM Tuning for Containers

The following JVM flags are set via `JAVA_TOOL_OPTIONS`:
- `-XX:+UseContainerSupport`: Enables container-aware memory/CPU detection
- `-XX:MaxRAMPercentage=75.0`: Uses 75% of container memory for JVM heap
- `-XX:+UnlockExperimentalVMOptions`: Enables experimental JVM features
- `-Xms256m -Xmx512m`: Initial and maximum heap size

For production with 2Gi memory limit, consider:
```
-Xms512m -Xmx1536m -XX:MaxRAMPercentage=75.0
```

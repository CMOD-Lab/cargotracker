# Eclipse Cargo Tracker – Deployment Guide

## Overview

This guide covers building, containerising, and deploying the **Eclipse Cargo Tracker** application to **Azure Kubernetes Service (AKS)**.

| Property | Value |
|---|---|
| Application | Eclipse Cargo Tracker |
| Artifact ID | `cargo-tracker` |
| Packaging | WAR (Jakarta EE) |
| Runtime | Payara Micro 6.2025.3 |
| Java Version | 11 (Amazon Corretto 11) |
| Build Tool | Maven 3.9.x |
| Target Platform | Azure AKS |
| Application Port | 8080 |
| Health Endpoint | `/cargo-tracker/rest/health` |

---

## Prerequisites

### Local Development
- **Java 11** (Amazon Corretto 11 or Eclipse Temurin 11)
- **Maven 3.9+** (`mvn --version`)
- **Docker Desktop** 24+ (`docker --version`)
- **Docker Compose** v2+ (`docker compose version`)

### Azure AKS Deployment
- **Azure CLI** 2.50+ (`az --version`)
- **kubectl** 1.27+ (`kubectl version --client`)
- **Azure Subscription** with permissions to create AKS resources
- **Azure Container Registry (ACR)** or Docker Hub account

---

## Project Structure

```
Monoservices/
├── Dockerfile                  # Multi-stage build (Maven builder + Corretto 11 runtime)
├── .dockerignore               # Excludes target/, wrapper files, IDE files
├── docker-compose.yml          # Single-service local development stack
├── pom.xml                     # Maven build descriptor (Java 11, WAR packaging)
├── post-boot-commands.asadmin  # Payara Micro post-boot configuration
├── src/
│   └── main/
│       ├── java/               # Application source code (Jakarta EE / DDD)
│       ├── resources/          # persistence.xml, batch jobs
│       ├── liberty/config/     # OpenLiberty server.xml (alternative runtime)
│       └── webapp/             # JSF/Faces web resources, WEB-INF
├── kubernetes/
│   ├── namespace.yaml          # Kubernetes namespace: cargo-tracker
│   ├── deployment.yaml         # Deployment with 2 replicas, health probes
│   ├── service.yaml            # ClusterIP service on port 80 → 8080
│   └── ingress.yaml            # Azure Application Gateway Ingress
├── scripts/
│   ├── build-push.sh           # Linux/macOS: build & push to ACR or Docker Hub
│   ├── build-push.bat          # Windows: build & push to ACR or Docker Hub
│   ├── deploy-image.sh         # Linux/macOS: deploy to AKS
│   └── deploy-image.bat        # Windows: deploy to AKS
└── docs/
    └── DEPLOYMENT.md           # This file
```

---

## 1. Local Development with Docker Compose

### Build and Start

```bash
# Build the Docker image and start the container
docker compose up --build

# Run in background
docker compose up --build -d
```

### Access the Application

- **Application UI**: http://localhost:8080/cargo-tracker/
- **Health Check**: http://localhost:8080/cargo-tracker/rest/health
- **REST API**: http://localhost:8080/cargo-tracker/rest/

### Stop the Application

```bash
docker compose down
# Remove volumes too
docker compose down -v
```

### Environment Variables (docker-compose.yml)

| Variable | Default | Description |
|---|---|---|
| `JAVA_OPTS` | `-Xms256m -Xmx512m ...` | JVM startup options |
| `DB_DRIVER_CLASS` | `org.h2.jdbcx.JdbcDataSource` | JDBC driver class |
| `DB_JDBC_URL` | `jdbc:h2:file:./cargo-tracker-data/...` | JDBC connection URL |
| `DB_USER` | _(empty)_ | Database username |
| `DB_PASSWORD` | _(empty)_ | Database password |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/...` | Internal routing service URL |
| `SEND_ERROR_IN_RESPONSE` | `true` | Include validation errors in REST responses |

Override any variable by creating a `.env` file in the project root:

```env
DB_JDBC_URL=jdbc:postgresql://my-db-host:5432/cargotracker
DB_DRIVER_CLASS=org.postgresql.ds.PGPoolingDataSource
DB_USER=myuser
DB_PASSWORD=mypassword
```

---

## 2. Build and Push Docker Image

### Linux / macOS

```bash
chmod +x scripts/build-push.sh
bash scripts/build-push.sh
```

### Windows

```cmd
scripts\build-push.bat
```

The script will prompt you to:
1. Choose registry type: **Azure ACR** or **Docker Hub**
2. Enter registry credentials
3. Enter an image tag (defaults to `latest`)

The image name is automatically sanitised to lowercase with hyphens: `cargo-tracker`.

### Manual Build

```bash
# Build
docker build -t cargo-tracker:latest .

# Tag for ACR
docker tag cargo-tracker:latest <acr-name>.azurecr.io/cargo-tracker:latest

# Push to ACR
az acr login --name <acr-name>
docker push <acr-name>.azurecr.io/cargo-tracker:latest
```

---

## 3. Azure AKS Deployment

### 3.1 Azure Prerequisites

```bash
# Login to Azure
az login

# Set subscription (if multiple)
az account set --subscription "<subscription-id>"

# Verify
az account show
```

### 3.2 Create Azure Container Registry (if not existing)

```bash
az group create --name cargo-tracker-rg --location eastus

az acr create \
  --resource-group cargo-tracker-rg \
  --name <acr-name> \
  --sku Basic
```

### 3.3 Create AKS Cluster (if not existing)

```bash
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --attach-acr <acr-name> \
  --enable-addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --generate-ssh-keys
```

### 3.4 Deploy Using Script

#### Linux / macOS

```bash
chmod +x scripts/deploy-image.sh
bash scripts/deploy-image.sh
```

#### Windows

```cmd
scripts\deploy-image.bat
```

The script will prompt for:
- Azure Resource Group name
- AKS Cluster name
- Full Docker image URI (e.g. `myregistry.azurecr.io/cargo-tracker:latest`)
- Database configuration (optional, defaults to embedded H2)

### 3.5 Manual Kubernetes Deployment

```bash
# Configure kubectl
az aks get-credentials --resource-group cargo-tracker-rg --name cargo-tracker-aks

# Update image URI in deployment.yaml
sed -i 's|{{IMAGE_URI}}|<acr-name>.azurecr.io/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{DB_DRIVER_CLASS}}|org.h2.jdbcx.JdbcDataSource|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}||g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}||g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml

# Apply manifests
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# Verify
kubectl get pods,svc,ingress -n cargo-tracker
```

---

## 4. Kubernetes Manifest Reference

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: `{{IMAGE_URI}}` (replaced at deploy time)
- **Port**: 8080 (Payara Micro HTTP)
- **Resources**:
  - Requests: `cpu: 250m`, `memory: 512Mi`
  - Limits: `cpu: 500m`, `memory: 1Gi`
- **Liveness Probe**: `GET /cargo-tracker/rest/health` (initial delay: 90s)
- **Readiness Probe**: `GET /cargo-tracker/rest/health` (initial delay: 60s)
- **Security**: Runs as non-root user (UID 1000)

### service.yaml
- **Type**: ClusterIP
- **Port mapping**: 80 → 8080

### ingress.yaml
- **Class**: `azure/application-gateway`
- **Host**: `cargo-tracker.example.com` (update to your actual domain)
- **Path**: `/` (all traffic routed to the service)

---

## 5. Configuration Management

### Production Database (PostgreSQL)

For production deployments, override the H2 embedded database with PostgreSQL:

```bash
# Build with cloud profile (includes PostgreSQL driver)
mvn clean package -Pcloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://your-db-host:5432/cargotracker" \
  -DpostgreSqlUsername="dbuser" \
  -DpostgreSqlPassword="dbpassword"
```

Set environment variables in `kubernetes/deployment.yaml`:

```yaml
- name: DB_DRIVER_CLASS
  value: "org.postgresql.ds.PGPoolingDataSource"
- name: DB_JDBC_URL
  value: "jdbc:postgresql://your-db-host:5432/cargotracker"
- name: DB_USER
  value: "dbuser"
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: cargo-tracker-db-secret
      key: password
```

### Kubernetes Secrets for Sensitive Data

```bash
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=password='your-db-password' \
  -n cargo-tracker
```

---

## 6. Scaling and Management

### Horizontal Pod Autoscaler

```bash
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=<acr-name>.azurecr.io/cargo-tracker:v2.0 \
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

## 7. Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n cargo-tracker

# Describe pod for events
kubectl describe pod <pod-name> -n cargo-tracker

# View logs
kubectl logs <pod-name> -n cargo-tracker
kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=200
```

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| `ImagePullBackOff` | Cannot pull image from registry | Verify ACR credentials: `az aks update --attach-acr <acr-name>` |
| `CrashLoopBackOff` | Application startup failure | Check logs: `kubectl logs <pod> -n cargo-tracker` |
| `OOMKilled` | Insufficient memory | Increase memory limits in `deployment.yaml` |
| Health probe failing | Slow JVM startup | Increase `initialDelaySeconds` in probes (currently 90s) |
| Ingress not routing | AGIC not configured | Verify Application Gateway Ingress Controller is enabled |

### JVM Startup Tuning

Payara Micro on Java 11 may take 60–120 seconds to start. If health probes fail:

```yaml
livenessProbe:
  initialDelaySeconds: 120   # Increase if needed
  periodSeconds: 30
  failureThreshold: 5
readinessProbe:
  initialDelaySeconds: 90
  periodSeconds: 15
  failureThreshold: 5
```

### Ingress IP

```bash
kubectl get ingress cargo-tracker-ingress -n cargo-tracker
# Note the ADDRESS field - update DNS to point your domain to this IP
```

---

## 8. Security Considerations

1. **Non-root container**: The application runs as UID 1000 (`payara` user)
2. **Secrets management**: Use Kubernetes Secrets or Azure Key Vault for passwords
3. **Network policies**: Consider adding NetworkPolicy to restrict pod-to-pod traffic
4. **Image scanning**: Enable ACR vulnerability scanning
5. **RBAC**: Apply least-privilege RBAC for the service account
6. **TLS**: Configure TLS termination at the Application Gateway level

---

## 9. Java / Jakarta EE Specific Notes

- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF, JMS, Batch)
- **Runtime**: Payara Micro 6.x (Jakarta EE 10 compatible)
- **JVM flags**: `UseContainerSupport` and `MaxRAMPercentage=75.0` ensure the JVM respects container memory limits
- **Database**: H2 embedded by default; PostgreSQL supported via `cloud` Maven profile
- **JMS**: Internal Payara Micro messaging (no external broker required for default profile)
- **Health endpoint**: Custom JAX-RS endpoint at `/cargo-tracker/rest/health` returns `{"status":"UP",...}`
- **Context root**: Application deployed at `/cargo-tracker` context root

---

## 10. Quick Reference Commands

```bash
# Build image
docker build -t cargo-tracker:latest .

# Run locally
docker compose up -d

# Push to ACR
az acr login --name <acr-name>
docker push <acr-name>.azurecr.io/cargo-tracker:latest

# Deploy to AKS
bash scripts/deploy-image.sh

# Check status
kubectl get all -n cargo-tracker

# View logs
kubectl logs -l app=cargo-tracker -n cargo-tracker -f

# Scale
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker

# Rollback
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
```

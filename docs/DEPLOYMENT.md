# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment process for the **Eclipse Cargo Tracker** application on **Azure Kubernetes Service (AKS)**. The application is a Jakarta EE 10 web application built with Maven, packaged as a WAR, and deployed on Payara Micro.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (Payara Micro)
- **Java Version**: 11
- **Build Tool**: Maven
- **Package Type**: WAR
- **Application Port**: 8080 (HTTP), 8081 (HTTPS)
- **Base Image**: `mcr.microsoft.com/openjdk/jdk:11-ubuntu`

---

## Prerequisites

### Local Development
- Java 11 JDK
- Maven 3.9+
- Docker Desktop (latest)
- Git

### Azure AKS Deployment
- Azure CLI (`az`) - [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- kubectl - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- Active Azure Subscription
- Azure Container Registry (ACR) or Docker Hub account
- AKS Cluster (see setup below)

---

## Project Structure

```
modernize/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build configuration
├── src/
│   ├── main/
│   │   ├── java/                 # Application source code
│   │   ├── webapp/               # Web resources (JSF/XHTML)
│   │   └── resources/            # Configuration files
│   └── test/                     # Test sources
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # Azure Application Gateway ingress
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push
│   ├── build-push.bat            # Windows build & push
│   ├── deploy-image.sh           # Linux/macOS AKS deploy
│   └── deploy-image.bat          # Windows AKS deploy
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development Setup

### 1. Build the Application Locally

```bash
# Build WAR with cloud profile (PostgreSQL support)
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="postgres"
```

### 2. Run with Docker Compose

```bash
# Start the application (ensure PostgreSQL is available externally)
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f cargo-tracker

# Stop
docker-compose down
```

> **Note**: The `docker-compose.yml` contains only the application service. You must provide a PostgreSQL database separately. Update `DB_JDBC_URL`, `DB_USER`, and `DB_PASSWORD` in `docker-compose.yml` to point to your database.

### 3. Access the Application

- Application: http://localhost:8080/cargo-tracker/
- Admin Interface: http://localhost:8080/cargo-tracker/admin/
- Event Logger: http://localhost:8080/cargo-tracker/event-logger/

---

## Docker Build

### Build Image Manually

```bash
# Build the Docker image
docker build -t cargo-tracker:latest .

# Run the container
docker run -d \
  -p 8080:8080 \
  -e DB_JDBC_URL="jdbc:postgresql://host.docker.internal:5432/cargotracker" \
  -e DB_USER="postgres" \
  -e DB_PASSWORD="postgres" \
  -e GRAPH_TRAVERSAL_URL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path" \
  --name cargo-tracker \
  cargo-tracker:latest
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0` |
| `DB_DRIVER_CLASS` | JDBC driver class | `org.postgresql.ds.PGPoolingDataSource` |
| `DB_JDBC_URL` | Database JDBC URL | `jdbc:postgresql://localhost:5432/cargotracker` |
| `DB_USER` | Database username | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `GRAPH_TRAVERSAL_URL` | Graph traversal service URL | `http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path` |
| `TZ` | Timezone | `UTC` |

---

## Build and Push to Registry

### Using the Build Script (Linux/macOS)

```bash
# Make script executable
chmod +x scripts/build-push.sh

# Run from project root
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type (Azure ACR or Docker Hub)
3. Provide registry credentials

### Using the Build Script (Windows)

```cmd
scripts\build-push.bat
```

### Manual Build and Push to ACR

```bash
# Login to ACR
az acr login --name <your-acr-name>

# Build and tag
docker build -t <your-acr-name>.azurecr.io/cargo-tracker:latest .

# Push
docker push <your-acr-name>.azurecr.io/cargo-tracker:latest
```

---

## Azure AKS Setup

### 1. Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Create Resource Group (if needed)

```bash
az group create --name cargo-tracker-rg --location eastus
```

### 3. Create Azure Container Registry (if needed)

```bash
az acr create \
  --resource-group cargo-tracker-rg \
  --name <your-acr-name> \
  --sku Basic

# Enable admin access
az acr update --name <your-acr-name> --admin-enabled true
```

### 4. Create AKS Cluster (if needed)

```bash
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --enable-addons monitoring \
  --attach-acr <your-acr-name> \
  --generate-ssh-keys
```

### 5. Install Application Gateway Ingress Controller (AGIC)

```bash
# Enable AGIC addon
az aks enable-addons \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16"
```

### 6. Configure kubectl

```bash
az aks get-credentials \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

## Kubernetes Deployment

### Using the Deploy Script (Linux/macOS)

```bash
# Make script executable
chmod +x scripts/deploy-image.sh

# Run from project root
./scripts/deploy-image.sh
```

The script will prompt for:
- Azure Resource Group name
- AKS Cluster name
- Docker image URI (full path with tag)
- Database connection details
- Graph traversal URL

### Using the Deploy Script (Windows)

```cmd
scripts\deploy-image.bat
```

### Manual Kubernetes Deployment

```bash
# 1. Update deployment.yaml with your image URI
sed -i 's|{{IMAGE_URI}}|<your-acr>.azurecr.io/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:postgresql://your-db-host:5432/cargotracker|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}|postgres|g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|your-password|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml

# 2. Apply manifests in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# 3. Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# 4. Verify
kubectl get pods,svc,ingress -n cargo-tracker
```

---

## Kubernetes Manifest Descriptions

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
Deploys 2 replicas of the cargo-tracker application with:
- Resource requests: 250m CPU, 512Mi memory
- Resource limits: 500m CPU, 1Gi memory
- TCP socket liveness probe on port 8080 (initial delay: 90s - allows Payara Micro startup)
- TCP socket readiness probe on port 8080 (initial delay: 60s)
- Environment variable placeholders for database and application configuration

### service.yaml
Creates a `ClusterIP` service (`cargo-tracker-service`) that routes traffic to port 8080 of the application pods.

### ingress.yaml
Creates an Azure Application Gateway Ingress with:
- Host: `cargo-tracker.example.com` (update to your domain)
- Cookie-based session affinity (important for JSF stateful sessions)
- Routes all traffic (`/`) to the service

---

## Scaling and Management

### Scale Deployment

```bash
# Scale to 3 replicas
kubectl scale deployment cargo-tracker -n cargo-tracker --replicas=3

# Auto-scale (HPA)
kubectl autoscale deployment cargo-tracker \
  -n cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=5
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
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker --to-revision=2
```

---

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n cargo-tracker
kubectl describe pod <pod-name> -n cargo-tracker
```

### View Application Logs

```bash
# All pods
kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=200

# Specific pod
kubectl logs <pod-name> -n cargo-tracker

# Follow logs
kubectl logs -f <pod-name> -n cargo-tracker
```

### Common Issues

#### Pods in CrashLoopBackOff
```bash
# Check logs for startup errors
kubectl logs <pod-name> -n cargo-tracker --previous

# Common causes:
# - Database connection failure: verify DB_JDBC_URL, DB_USER, DB_PASSWORD
# - Insufficient memory: increase memory limits in deployment.yaml
# - Payara Micro startup timeout: increase initialDelaySeconds in probes
```

#### Pods in Pending State
```bash
# Check events
kubectl describe pod <pod-name> -n cargo-tracker

# Common causes:
# - Insufficient cluster resources: scale up node pool
# - Image pull failure: verify image URI and ACR credentials
```

#### Ingress Not Accessible
```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Check Application Gateway
az network application-gateway show \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-appgw

# Verify AGIC is running
kubectl get pods -n kube-system | grep ingress
```

#### Database Connection Issues
```bash
# Test database connectivity from pod
kubectl exec -it <pod-name> -n cargo-tracker -- \
  sh -c "nc -zv <db-host> 5432"

# Verify environment variables
kubectl exec -it <pod-name> -n cargo-tracker -- env | grep DB_
```

#### JVM Memory Issues
```bash
# Check memory usage
kubectl top pods -n cargo-tracker

# Increase memory limits in deployment.yaml:
# limits:
#   memory: "2Gi"
# And update JAVA_OPTS:
# -Xmx1g -Xms512m
```

---

## Security Considerations

1. **Non-root Container**: The application runs as the `payara` user (non-root) inside the container.
2. **Secrets Management**: Use Kubernetes Secrets for sensitive values (DB_PASSWORD):
   ```bash
   kubectl create secret generic cargo-tracker-secrets \
     --from-literal=db-password=<your-password> \
     -n cargo-tracker
   ```
   Then reference in deployment.yaml:
   ```yaml
   - name: DB_PASSWORD
     valueFrom:
       secretKeyRef:
         name: cargo-tracker-secrets
         key: db-password
   ```
3. **Network Policies**: Consider adding Kubernetes NetworkPolicies to restrict pod-to-pod communication.
4. **TLS/HTTPS**: Configure TLS termination at the Application Gateway level.
5. **Image Scanning**: Enable ACR vulnerability scanning for the container image.
6. **RBAC**: Use Azure RBAC and Kubernetes RBAC to restrict access to the cluster.

---

## Jakarta EE / Payara Micro Notes

- **Startup Time**: Payara Micro typically takes 30-90 seconds to start. The liveness probe has a 90-second initial delay to accommodate this.
- **Session Affinity**: The ingress is configured with cookie-based affinity, which is important for JSF stateful sessions.
- **JMS Queues**: The application uses JMS queues (CargoHandledQueue, MisdirectedCargoQueue, etc.) which are embedded in Payara Micro.
- **H2 vs PostgreSQL**: The default Maven profile uses H2 (file-based). The `cloud` profile uses PostgreSQL. The Docker image is built with the `cloud` profile.
- **Context Root**: The application is deployed at `/` context root (configured in Payara Micro startup command).
- **Graph Traversal URL**: The `GRAPH_TRAVERSAL_URL` environment variable must point to the REST endpoint for cargo routing. In Kubernetes, this should reference the service name.

---

## Configuration Management

### Update Application Configuration

To update environment variables without rebuilding the image:

```bash
# Edit deployment
kubectl edit deployment cargo-tracker -n cargo-tracker

# Or patch specific env var
kubectl patch deployment cargo-tracker -n cargo-tracker \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env/2/value", "value": "new-value"}]'
```

### Using ConfigMaps

```bash
# Create ConfigMap
kubectl create configmap cargo-tracker-config \
  --from-literal=GRAPH_TRAVERSAL_URL="http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path" \
  -n cargo-tracker

# Reference in deployment.yaml
# envFrom:
#   - configMapRef:
#       name: cargo-tracker-config
```

---

*Generated for Eclipse Cargo Tracker v3.1-SNAPSHOT | Target Platform: Azure AKS*

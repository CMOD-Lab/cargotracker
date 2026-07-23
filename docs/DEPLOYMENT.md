# Eclipse Cargo Tracker - Deployment Guide

## Azure Kubernetes Service (AKS) Deployment

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Local Development with Docker Compose](#local-development-with-docker-compose)
5. [Building and Pushing the Docker Image](#building-and-pushing-the-docker-image)
6. [Azure AKS Deployment](#azure-aks-deployment)
7. [Kubernetes Manifest Descriptions](#kubernetes-manifest-descriptions)
8. [Configuration Management](#configuration-management)
9. [Scaling and Management](#scaling-and-management)
10. [Troubleshooting](#troubleshooting)
11. [Security Considerations](#security-considerations)
12. [Jakarta EE Specific Notes](#jakarta-ee-specific-notes)

---

## Overview

**Eclipse Cargo Tracker** is a Jakarta EE 10 reference application demonstrating Domain-Driven Design (DDD) patterns. It runs on **Payara Micro** (Jakarta EE application server) and is packaged as a **WAR** file.

| Property         | Value                                      |
|------------------|--------------------------------------------|
| Framework        | Jakarta EE 10 (Payara Micro)               |
| Java Version     | 11                                         |
| Build Tool       | Maven 3.9.x                                |
| Package Type     | WAR                                        |
| Application Port | 8080 (HTTP), 8081 (HTTPS)                  |
| Context Root     | `/cargo-tracker`                           |
| Database         | PostgreSQL (production), H2 (development)  |
| Base Image       | mcr.microsoft.com/openjdk/jdk:11-ubuntu    |

---

## Prerequisites

### Local Development
- **Docker Desktop** 24.x or later
- **Docker Compose** v2.x or later
- **Java 11** (for local Maven builds)
- **Maven 3.9.x** (for local builds)

### Azure AKS Deployment
- **Azure CLI** (`az`) 2.50.0 or later
  ```bash
  # Install Azure CLI
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  # Verify
  az --version
  ```
- **kubectl** 1.27 or later
  ```bash
  # Install kubectl via Azure CLI
  az aks install-cli
  # Verify
  kubectl version --client
  ```
- **Azure Subscription** with the following resources:
  - Azure Kubernetes Service (AKS) cluster
  - Azure Container Registry (ACR) or Docker Hub account
  - Azure Application Gateway Ingress Controller (AGIC) installed on AKS
  - PostgreSQL database (Azure Database for PostgreSQL recommended)

---

## Project Structure

```
BackendServices/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build descriptor
├── post-boot-commands.asadmin    # Payara Micro post-boot commands
├── src/
│   └── main/
│       ├── java/                 # Java source code
│       ├── webapp/               # Web application resources (JSF/XHTML)
│       └── liberty/config/       # OpenLiberty server configuration
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # Azure Application Gateway ingress
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push script
│   ├── build-push.bat            # Windows build & push script
│   ├── deploy-image.sh           # Linux/macOS AKS deploy script
│   └── deploy-image.bat          # Windows AKS deploy script
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development with Docker Compose

### Step 1: Set Up Environment Variables

Create a `.env` file in the project root:

```bash
# .env
POSTGRES_HOST=host.docker.internal
POSTGRES_PORT=5432
POSTGRES_DB=cargotracker
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password
```

> **Note**: For local development, the application uses an embedded H2 database by default. PostgreSQL is required for production/cloud deployments.

### Step 2: Build and Start the Application

```bash
# Build and start the application container
docker-compose up --build

# Run in detached mode
docker-compose up --build -d

# View logs
docker-compose logs -f cargo-tracker
```

### Step 3: Access the Application

Once the container is running (allow ~90 seconds for Payara Micro to start):

- **Application**: http://localhost:8080/cargo-tracker
- **Booking Interface**: http://localhost:8080/cargo-tracker/booking/booking.xhtml
- **Tracking Interface**: http://localhost:8080/cargo-tracker/public/track.xhtml
- **Event Logger**: http://localhost:8080/cargo-tracker/event-logger/index.xhtml

### Step 4: Stop the Application

```bash
docker-compose down

# Remove volumes as well
docker-compose down -v
```

---

## Building and Pushing the Docker Image

### Linux/macOS

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run the build and push script
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type (Azure ACR or Docker Hub)
3. Provide registry credentials

### Windows

```cmd
scripts\build-push.bat
```

### Manual Docker Build

```bash
# Build the image
docker build -t cargo-tracker:latest .

# Tag for ACR
docker tag cargo-tracker:latest myregistry.azurecr.io/cargo-tracker:latest

# Push to ACR
az acr login --name myregistry
docker push myregistry.azurecr.io/cargo-tracker:latest
```

### Maven Build (for local WAR generation)

```bash
# Build with default Payara profile (H2 database)
mvn clean package -Ppayara -DskipTests

# Build with cloud profile (PostgreSQL)
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="your_password"
```

---

## Azure AKS Deployment

### Step 1: Log in to Azure

```bash
az login
az account set --subscription "your-subscription-id"
```

### Step 2: Create or Configure AKS Cluster (if not existing)

```bash
# Create resource group
az group create --name cargo-tracker-rg --location eastus

# Create AKS cluster with Application Gateway Ingress Controller
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --enable-addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group cargo-tracker-rg --name cargo-tracker-aks
```

### Step 3: Set Up Azure Container Registry (ACR)

```bash
# Create ACR
az acr create --resource-group cargo-tracker-rg \
  --name cargotrackercr --sku Basic

# Attach ACR to AKS (allows AKS to pull images)
az aks update --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --attach-acr cargotrackercr
```

### Step 4: Build and Push the Image

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
# Select: 1 (Azure ACR)
# ACR name: cargotrackercr
# Tag: v3.1
```

### Step 5: Deploy to AKS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- Azure Resource Group name
- AKS Cluster name
- Full Docker image URI (e.g., `cargotrackercr.azurecr.io/cargo-tracker:v3.1`)
- PostgreSQL connection details

### Step 6: Verify Deployment

```bash
# Check pods
kubectl get pods -n cargo-tracker

# Check services
kubectl get svc -n cargo-tracker

# Check ingress
kubectl get ingress -n cargo-tracker

# View application logs
kubectl logs -f deployment/cargo-tracker -n cargo-tracker
```

### Step 7: Access the Application

```bash
# Get ingress IP
kubectl get ingress cargo-tracker-ingress -n cargo-tracker

# Access the application (replace with actual IP or hostname)
# http://<INGRESS_IP>/cargo-tracker
```

---

## Kubernetes Manifest Descriptions

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
Deploys 2 replicas of the Cargo Tracker application with:
- **Image**: Pulled from the specified registry
- **Ports**: 8080 (HTTP), 8081 (HTTPS)
- **Resources**: 250m CPU / 512Mi memory (requests), 500m CPU / 1Gi memory (limits)
- **Liveness Probe**: TCP socket check on port 8080 (90s initial delay for JVM startup)
- **Readiness Probe**: TCP socket check on port 8080 (60s initial delay)
- **Environment Variables**: PostgreSQL connection details, JVM options, timezone

### service.yaml
Creates a `ClusterIP` service exposing:
- Port 80 → Container port 8080 (HTTP)
- Port 443 → Container port 8081 (HTTPS)

### ingress.yaml
Configures Azure Application Gateway Ingress Controller with:
- Host: `cargo-tracker.example.com` (update with your actual domain)
- Path: `/` → `cargo-tracker-service:80`
- Cookie-based session affinity (important for JSF stateful sessions)

> **Important**: Update `cargo-tracker.example.com` in `kubernetes/ingress.yaml` with your actual domain before deploying.

---

## Configuration Management

### Environment Variables

| Variable           | Description                    | Default     |
|--------------------|--------------------------------|-------------|
| `POSTGRES_HOST`    | PostgreSQL server hostname     | localhost   |
| `POSTGRES_PORT`    | PostgreSQL server port         | 5432        |
| `POSTGRES_DB`      | PostgreSQL database name       | cargotracker|
| `POSTGRES_USER`    | PostgreSQL username            | postgres    |
| `POSTGRES_PASSWORD`| PostgreSQL password            | postgres    |
| `JAVA_OPTS`        | JVM options                    | See Dockerfile |
| `TZ`               | Timezone                       | UTC         |

### Using Kubernetes Secrets for Sensitive Data

For production, store database credentials as Kubernetes Secrets:

```bash
# Create secret
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=POSTGRES_USER=myuser \
  --from-literal=POSTGRES_PASSWORD=mysecurepassword \
  -n cargo-tracker
```

Then update `deployment.yaml` to reference the secret:

```yaml
env:
  - name: POSTGRES_USER
    valueFrom:
      secretKeyRef:
        name: cargo-tracker-db-secret
        key: POSTGRES_USER
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: cargo-tracker-db-secret
        key: POSTGRES_PASSWORD
```

### Azure Database for PostgreSQL

For production, use Azure Database for PostgreSQL:

```bash
# Create PostgreSQL server
az postgres flexible-server create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-db \
  --location eastus \
  --admin-user pgadmin \
  --admin-password "YourSecurePassword123!" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 15

# Create database
az postgres flexible-server db create \
  --resource-group cargo-tracker-rg \
  --server-name cargo-tracker-db \
  --database-name cargotracker
```

---

## Scaling and Management

### Manual Scaling

```bash
# Scale to 3 replicas
kubectl scale deployment/cargo-tracker --replicas=3 -n cargo-tracker

# Scale down
kubectl scale deployment/cargo-tracker --replicas=1 -n cargo-tracker
```

### Horizontal Pod Autoscaler (HPA)

```bash
# Create HPA (requires metrics-server)
kubectl autoscale deployment/cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=5 \
  -n cargo-tracker

# Check HPA status
kubectl get hpa -n cargo-tracker
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=myregistry.azurecr.io/cargo-tracker:v3.2 \
  -n cargo-tracker

# Monitor rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# Rollback if needed
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# View rollout history
kubectl rollout history deployment/cargo-tracker -n cargo-tracker
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n cargo-tracker

# Describe pod for events
kubectl describe pod <pod-name> -n cargo-tracker

# View pod logs
kubectl logs <pod-name> -n cargo-tracker

# View previous container logs (if crashed)
kubectl logs <pod-name> -n cargo-tracker --previous
```

### Common Issues

#### 1. Payara Micro Startup Timeout
Payara Micro can take 60-90 seconds to start. If pods are failing readiness checks:
```bash
# Increase initialDelaySeconds in deployment.yaml
# livenessProbe.initialDelaySeconds: 120
# readinessProbe.initialDelaySeconds: 90
kubectl edit deployment/cargo-tracker -n cargo-tracker
```

#### 2. Database Connection Failure
```bash
# Verify PostgreSQL environment variables
kubectl exec -it <pod-name> -n cargo-tracker -- env | grep POSTGRES

# Test database connectivity from pod
kubectl exec -it <pod-name> -n cargo-tracker -- sh -c "nc -zv $POSTGRES_HOST $POSTGRES_PORT"
```

#### 3. Image Pull Errors
```bash
# Check if ACR is attached to AKS
az aks check-acr --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --acr cargotrackercr

# Re-attach ACR if needed
az aks update --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --attach-acr cargotrackercr
```

#### 4. Ingress Not Getting IP
```bash
# Check AGIC status
kubectl get pods -n kube-system | grep ingress

# Check ingress events
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Verify Application Gateway exists
az network application-gateway list --resource-group cargo-tracker-rg
```

#### 5. Out of Memory (OOM)
```bash
# Increase memory limits in deployment.yaml
# resources.limits.memory: "2Gi"
# Also update JAVA_OPTS: -Xmx1g -Xms512m

kubectl edit deployment/cargo-tracker -n cargo-tracker
```

### Useful Diagnostic Commands

```bash
# Get all resources in namespace
kubectl get all -n cargo-tracker

# Check resource usage
kubectl top pods -n cargo-tracker

# Execute shell in running pod
kubectl exec -it <pod-name> -n cargo-tracker -- bash

# Port-forward for local debugging
kubectl port-forward deployment/cargo-tracker 8080:8080 -n cargo-tracker
# Then access: http://localhost:8080/cargo-tracker
```

---

## Security Considerations

1. **Non-root Container**: The Dockerfile runs Payara Micro as the `payara` user (non-root).

2. **Secrets Management**: Use Kubernetes Secrets or Azure Key Vault for sensitive data:
   ```bash
   # Azure Key Vault integration
   az keyvault create --name cargo-tracker-kv \
     --resource-group cargo-tracker-rg --location eastus
   ```

3. **Network Policies**: Restrict pod-to-pod communication:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: cargo-tracker-netpol
     namespace: cargo-tracker
   spec:
     podSelector:
       matchLabels:
         app: cargo-tracker
     policyTypes:
       - Ingress
     ingress:
       - from:
           - namespaceSelector:
               matchLabels:
                 name: cargo-tracker
   ```

4. **Image Scanning**: Enable ACR vulnerability scanning:
   ```bash
   az acr update --name cargotrackercr \
     --resource-group cargo-tracker-rg \
     --enable-quarantine
   ```

5. **RBAC**: Use least-privilege service accounts for the application pods.

6. **TLS/SSL**: Configure TLS termination at the Application Gateway level using Azure-managed certificates.

---

## Jakarta EE Specific Notes

### Payara Micro Configuration
- The application uses **Payara Micro** as the embedded Jakarta EE runtime
- Payara Micro is downloaded during the Docker build process
- The `post-boot-commands.asadmin` file configures the PostgreSQL JDBC driver and deploys the WAR

### JVM Tuning for Containers
The following JVM flags are configured for container-aware operation:
```
-Xmx512m                    # Maximum heap size
-Xms256m                    # Initial heap size
-XX:+UseContainerSupport    # Enable container memory awareness
-XX:MaxRAMPercentage=75.0   # Use 75% of container memory for heap
-XX:+UnlockExperimentalVMOptions
```

### Jakarta EE Profiles
The Maven build supports multiple profiles:
- `payara` (default): H2 embedded database, suitable for development
- `cloud`: PostgreSQL database, suitable for production/AKS deployment
- `glassfish`: GlassFish application server
- `openliberty`: IBM OpenLiberty application server

### Session Affinity
The Ingress is configured with cookie-based session affinity (`appgw.ingress.kubernetes.io/cookie-based-affinity: "true"`). This is important for JSF (Jakarta Faces) applications that maintain server-side session state.

### Context Root
The application is deployed with context root `/cargo-tracker`. All URLs will be prefixed with this path:
- Main page: `http://<host>/cargo-tracker/`
- REST API: `http://<host>/cargo-tracker/rest/`
- Graph traversal: `http://<host>/cargo-tracker/rest/graph-traversal/shortest-path`

### Database Migration
The application uses JPA with automatic schema generation. For production, consider using Flyway or Liquibase for controlled database migrations.

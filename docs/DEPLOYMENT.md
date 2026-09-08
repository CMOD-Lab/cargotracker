# Deployment Guide: cargo-tracker on Azure AKS

## Overview

This guide covers building, pushing, and deploying the **Eclipse Cargo Tracker** application (Jakarta EE 10, Java 11, Payara Micro) to **Azure Kubernetes Service (AKS)**.

- **Application**: Eclipse Cargo Tracker
- **Framework**: Jakarta EE 10 (Payara Micro)
- **Java Version**: 11
- **Build Tool**: Maven
- **Packaging**: WAR
- **Runtime Base Image**: `amazoncorretto:11`
- **Application Port**: 8080 (HTTP), 8081 (HTTPS)
- **Target Platform**: Azure AKS

---

## Prerequisites

### Local Development Tools
- **Docker** 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Java 11** (Amazon Corretto or Eclipse Temurin)
- **Maven 3.9+** ([Install Maven](https://maven.apache.org/install.html))

### Azure & Kubernetes Tools
- **Azure CLI** 2.50+ ([Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **kubectl** 1.27+ ([Install kubectl](https://kubernetes.io/docs/tasks/tools/))
- **Azure Subscription** with permissions to create AKS clusters and ACR registries

---

## Project Structure

```
BackendServices/
├── Dockerfile                    # Multi-stage build (Maven builder + amazoncorretto:11 runtime)
├── docker-compose.yml            # Local development with Docker Compose
├── .dockerignore                 # Excludes build artifacts and wrapper files
├── pom.xml                       # Maven build descriptor (Java 11, WAR packaging)
├── post-boot-commands.asadmin    # Payara Micro post-boot configuration
├── src/
│   └── main/
│       ├── java/                 # Jakarta EE application source
│       ├── webapp/               # JSF/Faces web resources
│       └── liberty/config/       # OpenLiberty server configuration
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace: cargo-tracker
│   ├── deployment.yaml           # Deployment with 2 replicas
│   ├── service.yaml              # ClusterIP service (port 80 → 8080)
│   └── ingress.yaml              # Azure Application Gateway Ingress
├── scripts/
│   ├── build-push.sh             # Linux/macOS: build & push to ACR or Docker Hub
│   ├── build-push.bat            # Windows: build & push to ACR or Docker Hub
│   ├── deploy-image.sh           # Linux/macOS: deploy to AKS
│   └── deploy-image.bat          # Windows: deploy to AKS
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development Setup

### 1. Build the Application Locally

```bash
# Build with default Payara profile (H2 in-memory database)
mvn clean package -DskipTests

# Build with cloud profile (PostgreSQL)
mvn clean package -DskipTests -Pcloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/postgres" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="postgres"
```

### 2. Run with Docker Compose

```bash
# Set environment variables
export DB_JDBC_URL="jdbc:postgresql://host.docker.internal:5432/postgres"
export DB_USERNAME="postgres"
export DB_PASSWORD="postgres"

# Build and start the application container
docker-compose up --build

# Access the application
open http://localhost:8080/cargo-tracker
```

### 3. Run Docker Compose in Background

```bash
docker-compose up -d
docker-compose logs -f cargo-tracker
docker-compose down
```

---

## Build and Push Docker Image

### Linux/macOS

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

### Manual Build and Push

```bash
# Build image
docker build -f Dockerfile -t cargo-tracker:latest .

# Tag for ACR
docker tag cargo-tracker:latest <ACR_NAME>.azurecr.io/cargo-tracker:latest

# Login to ACR
az acr login --name <ACR_NAME>

# Push
docker push <ACR_NAME>.azurecr.io/cargo-tracker:latest
```

---

## Azure AKS Deployment

### Step 1: Azure Prerequisites

```bash
# Login to Azure
az login

# Set subscription (if multiple)
az account set --subscription "<SUBSCRIPTION_ID>"

# Create Resource Group (if needed)
az group create --name cargo-tracker-rg --location eastus
```

### Step 2: Create Azure Container Registry (ACR)

```bash
# Create ACR
az acr create \
  --resource-group cargo-tracker-rg \
  --name <ACR_NAME> \
  --sku Basic

# Login to ACR
az acr login --name <ACR_NAME>
```

### Step 3: Create AKS Cluster

```bash
# Create AKS cluster with ACR integration
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --attach-acr <ACR_NAME> \
  --enable-addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --generate-ssh-keys

# Get credentials
az aks get-credentials \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 4: Build and Push Image to ACR

```bash
# Build and push using the script
./scripts/build-push.sh
# Select option 1 (Azure ACR), enter your ACR name and tag
```

### Step 5: Deploy to AKS

#### Using the Deploy Script (Recommended)

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- Azure Resource Group
- AKS Cluster name
- Full Docker image URI (e.g., `myregistry.azurecr.io/cargo-tracker:latest`)
- Database connection details (DB_JDBC_URL, DB_USERNAME, DB_PASSWORD)
- Graph traversal URL

#### Manual Deployment

```bash
# Apply manifests in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml   # After updating {{IMAGE_URI}} placeholder
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# Verify
kubectl get pods,svc,ingress -n cargo-tracker
```

---

## Kubernetes Manifest Details

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: Pulled from `{{IMAGE_URI}}` placeholder (replaced by deploy script)
- **Resources**: requests: `250m CPU / 512Mi RAM`, limits: `500m CPU / 1Gi RAM`
- **JVM Options**: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`
- **Health Probes**: TCP socket probes on port 8080 (Jakarta EE apps don't expose `/actuator/health`)
  - Liveness: initial delay 90s (JVM + Payara Micro startup time)
  - Readiness: initial delay 60s

### service.yaml
- **Type**: ClusterIP (internal cluster access)
- **Port mapping**: 80 → 8080 (HTTP), 443 → 8081 (HTTPS)

### ingress.yaml
- **Ingress class**: `azure/application-gateway`
- **Host**: `cargo-tracker.example.com` (update to your actual domain)
- **Cookie-based affinity**: enabled for session stickiness (Jakarta Faces requirement)

---

## Configuration Management

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DB_JDBC_URL` | PostgreSQL JDBC connection URL | `jdbc:postgresql://localhost:5432/postgres` |
| `DB_USERNAME` | Database username | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `GRAPH_TRAVERSAL_URL` | Internal graph traversal REST endpoint | `http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m -XX:+UseContainerSupport` |
| `TZ` | Timezone | `UTC` |

### Using Kubernetes Secrets for Sensitive Data

```bash
# Create secret for database credentials
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=DB_USERNAME=postgres \
  --from-literal=DB_PASSWORD=your-secure-password \
  -n cargo-tracker

# Reference in deployment.yaml (update env section):
# - name: DB_PASSWORD
#   valueFrom:
#     secretKeyRef:
#       name: cargo-tracker-db-secret
#       key: DB_PASSWORD
```

---

## Scaling and Management

### Horizontal Scaling

```bash
# Scale manually
kubectl scale deployment/cargo-tracker --replicas=3 -n cargo-tracker

# Configure Horizontal Pod Autoscaler
kubectl autoscale deployment/cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=<ACR_NAME>.azurecr.io/cargo-tracker:v2.0 \
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
# Check pod status
kubectl get pods -n cargo-tracker

# Describe pod for events
kubectl describe pod <POD_NAME> -n cargo-tracker

# Check logs
kubectl logs <POD_NAME> -n cargo-tracker
kubectl logs -f deployment/cargo-tracker -n cargo-tracker
```

### Common Issues

**Issue**: Pod stuck in `Pending` state
- **Cause**: Insufficient cluster resources
- **Fix**: Scale up node pool or reduce resource requests

**Issue**: Pod in `CrashLoopBackOff`
- **Cause**: Application startup failure (database connection, JVM OOM)
- **Fix**: Check logs with `kubectl logs <POD_NAME> -n cargo-tracker --previous`

**Issue**: Payara Micro startup timeout
- **Cause**: JVM startup + WAR deployment takes time
- **Fix**: Increase `initialDelaySeconds` in liveness/readiness probes

**Issue**: Database connection refused
- **Cause**: Incorrect `DB_JDBC_URL` or database not accessible from AKS
- **Fix**: Verify PostgreSQL is accessible from AKS VNet; check firewall rules

**Issue**: Ingress not routing traffic
- **Cause**: Application Gateway Ingress Controller not installed or misconfigured
- **Fix**: Verify AGIC addon: `az aks addon show --addon ingress-appgw -n <CLUSTER> -g <RG>`

### Exec into Running Pod

```bash
kubectl exec -it <POD_NAME> -n cargo-tracker -- /bin/bash
```

### Port Forward for Local Testing

```bash
kubectl port-forward deployment/cargo-tracker 8080:8080 -n cargo-tracker
# Access: http://localhost:8080/cargo-tracker
```

---

## Security Considerations

1. **Non-root container**: The application runs as user `payara` (UID 1000)
2. **Secrets management**: Use Kubernetes Secrets or Azure Key Vault for sensitive data
3. **Network policies**: Consider adding NetworkPolicy to restrict pod-to-pod communication
4. **Image scanning**: Enable ACR vulnerability scanning: `az acr task run --registry <ACR_NAME> --name scan`
5. **RBAC**: Use least-privilege service accounts for the application pods
6. **TLS**: Configure TLS termination at the Application Gateway level

---

## Java-Specific Notes

- **JVM Container Support**: `-XX:+UseContainerSupport` ensures JVM respects container memory limits
- **MaxRAMPercentage**: Set to 75% to leave headroom for OS and non-heap memory
- **Payara Micro**: Embedded Jakarta EE runtime; no separate application server installation needed
- **WAR Deployment**: The WAR is deployed at context root `/cargo-tracker` by default
- **JMS Queues**: Internal JMS queues (CargoHandledQueue, etc.) are managed by Payara Micro's embedded messaging engine
- **H2 vs PostgreSQL**: Use H2 for local development; PostgreSQL (`-Pcloud` Maven profile) for production/AKS

---

## Cleanup

```bash
# Remove all application resources
kubectl delete namespace cargo-tracker

# Delete AKS cluster (if no longer needed)
az aks delete --resource-group cargo-tracker-rg --name cargo-tracker-aks --yes --no-wait
```

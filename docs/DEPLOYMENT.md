# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment process for the **Eclipse Cargo Tracker** application on **Azure Kubernetes Service (AKS)**. The application is a Jakarta EE 10 web application built with Maven, packaged as a WAR, and deployed on Payara Micro.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (Payara Micro)
- **Build Tool**: Maven 3.9.x
- **Java Version**: 11
- **Package Type**: WAR
- **Application Port**: 8080
- **Target Platform**: Azure AKS

---

## Prerequisites

### Local Development
- Java 11 (JDK)
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
comp1/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build descriptor
├── post-boot-commands.asadmin    # Payara boot commands
├── src/
│   └── main/
│       ├── java/                 # Application source code
│       ├── resources/            # Persistence, batch configs
│       └── webapp/               # JSF/XHTML web resources
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # Azure Application Gateway ingress
├── scripts/
│   ├── build-push.sh             # Linux: build & push image
│   ├── build-push.bat            # Windows: build & push image
│   ├── deploy-image.sh           # Linux: deploy to AKS
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
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="postgres"
```

### 2. Run with Docker Compose

```bash
# Set environment variables for PostgreSQL (optional)
export POSTGRESQL_JDBC_URL="jdbc:postgresql://your-db-host:5432/cargotracker"
export POSTGRESQL_USERNAME="postgres"
export POSTGRESQL_PASSWORD="yourpassword"

# Start the application
docker-compose up --build

# Access the application
open http://localhost:8080/
```

### 3. Stop the Application

```bash
docker-compose down
docker-compose down -v   # Also remove volumes
```

---

## Docker Image Build & Push

### Linux/macOS

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type: Azure ACR or Docker Hub
3. Provide registry credentials

### Windows

```cmd
scripts\build-push.bat
```

### Manual Build

```bash
# Build image
docker build -f Dockerfile -t cargo-tracker:latest .

# Tag for ACR
docker tag cargo-tracker:latest myregistry.azurecr.io/cargo-tracker:latest

# Push to ACR
az acr login --name myregistry
docker push myregistry.azurecr.io/cargo-tracker:latest
```

---

## Azure AKS Deployment

### Step 1: Azure Prerequisites

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Create resource group (if needed)
az group create --name cargo-tracker-rg --location eastus
```

### Step 2: Create Azure Container Registry (ACR)

```bash
# Create ACR
az acr create \
  --resource-group cargo-tracker-rg \
  --name cargotrackercr \
  --sku Basic

# Login to ACR
az acr login --name cargotrackercr
```

### Step 3: Create AKS Cluster

```bash
# Create AKS cluster with Application Gateway Ingress Controller (AGIC)
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --enable-addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --attach-acr cargotrackercr \
  --generate-ssh-keys

# Get credentials
az aks get-credentials \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks
```

### Step 4: Build and Push Image

```bash
# Build and push to ACR
./scripts/build-push.sh
# Select: 1 (Azure ACR)
# ACR name: cargotrackercr
# Tag: v3.1
```

### Step 5: Deploy to AKS

#### Linux/macOS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

Provide when prompted:
- **Resource Group**: `cargo-tracker-rg`
- **AKS Cluster**: `cargo-tracker-aks`
- **Image URI**: `cargotrackercr.azurecr.io/cargo-tracker:v3.1`
- **POSTGRESQL_JDBC_URL**: `jdbc:postgresql://your-db-host:5432/cargotracker`
- **POSTGRESQL_USERNAME**: `postgres`
- **POSTGRESQL_PASSWORD**: `yourpassword`

#### Windows

```cmd
scripts\deploy-image.bat
```

### Step 6: Manual Manifest Deployment

```bash
# Apply manifests in order
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

## Kubernetes Manifest Descriptions

| File | Description |
|------|-------------|
| `namespace.yaml` | Creates the `cargo-tracker` namespace |
| `deployment.yaml` | Deploys 2 replicas of the application with resource limits and health probes |
| `service.yaml` | ClusterIP service exposing port 80 → 8080 |
| `ingress.yaml` | Azure Application Gateway ingress with cookie-based affinity |

### Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 250m | 500m |
| Memory | 512Mi | 1Gi |

---

## Configuration Management

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m -XX:+UseContainerSupport` |
| `TZ` | Timezone | `UTC` |
| `POSTGRESQL_JDBC_URL` | PostgreSQL JDBC URL | H2 file-based |
| `POSTGRESQL_USERNAME` | Database username | (empty) |
| `POSTGRESQL_PASSWORD` | Database password | (empty) |

### Using Kubernetes Secrets for Sensitive Data

```bash
# Create secret for database credentials
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=POSTGRESQL_USERNAME=postgres \
  --from-literal=POSTGRESQL_PASSWORD=yourpassword \
  -n cargo-tracker

# Reference in deployment.yaml (update env section):
# env:
#   - name: POSTGRESQL_PASSWORD
#     valueFrom:
#       secretKeyRef:
#         name: cargo-tracker-db-secret
#         key: POSTGRESQL_PASSWORD
```

---

## Scaling and Management

### Horizontal Scaling

```bash
# Scale manually
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker

# Configure Horizontal Pod Autoscaler
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=cargotrackercr.azurecr.io/cargo-tracker:v3.2 \
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

### Pod Issues

```bash
# List pods
kubectl get pods -n cargo-tracker

# Describe pod (events and status)
kubectl describe pod <pod-name> -n cargo-tracker

# View logs
kubectl logs <pod-name> -n cargo-tracker
kubectl logs <pod-name> -n cargo-tracker --previous   # Previous container logs

# Execute into pod
kubectl exec -it <pod-name> -n cargo-tracker -- /bin/bash
```

### Service Issues

```bash
# Check service endpoints
kubectl get endpoints -n cargo-tracker

# Test service connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://cargo-tracker-service.cargo-tracker.svc.cluster.local/
```

### Ingress Issues

```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Check Application Gateway logs in Azure Portal
# Navigate to: Application Gateway → Backend Health
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Pod in `CrashLoopBackOff` | JVM OOM or startup failure | Increase memory limits; check logs |
| Pod in `Pending` | Insufficient cluster resources | Scale node pool or reduce requests |
| Ingress not routing | AGIC not configured | Verify Application Gateway add-on is enabled |
| Database connection failed | Wrong JDBC URL or credentials | Verify env vars in deployment |
| Payara Micro slow start | JVM warmup | Increase `initialDelaySeconds` in probes |

---

## Security Considerations

1. **Non-root container**: The application runs as the `payara` user (non-root)
2. **Secrets management**: Use Kubernetes Secrets or Azure Key Vault for sensitive data
3. **Network policies**: Consider adding NetworkPolicy resources to restrict pod-to-pod traffic
4. **Image scanning**: Enable ACR vulnerability scanning
5. **RBAC**: Apply least-privilege RBAC for service accounts
6. **TLS**: Configure TLS termination at the Application Gateway level

```bash
# Enable TLS on ingress (update ingress.yaml):
# spec:
#   tls:
#     - hosts:
#         - cargo-tracker.example.com
#       secretName: cargo-tracker-tls
```

---

## Java / Jakarta EE Specific Notes

- **Payara Micro**: The application uses Payara Micro as an embedded Jakarta EE runtime
- **JVM Flags**: `-XX:+UseContainerSupport` ensures JVM respects container memory limits
- **MaxRAMPercentage**: Set to 75% to leave headroom for the OS and Payara overhead
- **Startup Time**: Payara Micro typically takes 30-90 seconds to start; probes are configured accordingly
- **Database**: Default profile uses H2 file-based database; use `cloud` Maven profile for PostgreSQL
- **JMS Queues**: The application uses internal JMS queues (Payara embedded messaging); no external broker required for default deployment
- **Context Root**: Application is deployed at `/` (root context)

---

## Useful Commands Reference

```bash
# View all resources in namespace
kubectl get all -n cargo-tracker

# Watch pod status
kubectl get pods -n cargo-tracker -w

# Port-forward for local testing
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker

# Delete deployment (cleanup)
kubectl delete namespace cargo-tracker
```

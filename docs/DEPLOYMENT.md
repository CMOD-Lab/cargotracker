# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment process for the **Eclipse Cargo Tracker** application on **Azure Kubernetes Service (AKS)**. The application is a Jakarta EE 10 web application running on Payara Micro, packaged as a WAR file.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (Payara Micro)
- **Java Version**: 11
- **Package Type**: WAR
- **Application Port**: 8080
- **Target Platform**: Azure AKS

---

## Prerequisites

### Local Development
- Docker Desktop 24.x or later
- Java 11 (Amazon Corretto 11 or Eclipse Temurin 11)
- Apache Maven 3.9.x
- Git

### Azure AKS Deployment
- Azure CLI (`az`) 2.50+
- `kubectl` 1.27+
- Active Azure subscription
- Azure Container Registry (ACR) or Docker Hub account
- AKS cluster (see setup below)

---

## Project Structure

```
cargotracker/
├── Dockerfile                  # Multi-stage Docker build
├── .dockerignore               # Docker build exclusions
├── docker-compose.yml          # Local development compose
├── pom.xml                     # Maven build descriptor
├── post-boot-commands.asadmin  # Payara Micro boot commands
├── src/                        # Application source code
├── kubernetes/
│   ├── namespace.yaml          # Kubernetes namespace
│   ├── deployment.yaml         # Kubernetes deployment
│   ├── service.yaml            # Kubernetes service (ClusterIP)
│   └── ingress.yaml            # Azure Application Gateway ingress
├── scripts/
│   ├── build-push.sh           # Linux/macOS build & push script
│   ├── build-push.bat          # Windows build & push script
│   ├── deploy-image.sh         # Linux/macOS AKS deploy script
│   └── deploy-image.bat        # Windows AKS deploy script
└── docs/
    └── DEPLOYMENT.md           # This file
```

---

## Local Development Setup

### 1. Build the Application Locally

```bash
# Build WAR using Maven (default Payara profile)
mvn clean package -DskipTests

# Build with cloud profile (PostgreSQL)
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="postgres"
```

### 2. Run with Docker Compose

```bash
# Build and start the application
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f cargo-tracker

# Stop the application
docker-compose down
```

The application will be available at: **http://localhost:8080/**

### 3. Environment Variables for Local Development

Edit `docker-compose.yml` to configure:

| Variable | Default | Description |
|---|---|---|
| `TZ` | `UTC` | Timezone |
| `JAVA_OPTS` | `-Xmx512m -Xms256m ...` | JVM options |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/rest/graph-traversal/shortest-path` | Graph traversal service URL |
| `DB_JDBC_URL` | `jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database` | Database JDBC URL |
| `DB_USER` | _(empty)_ | Database username |
| `DB_PASSWORD` | _(empty)_ | Database password |

---

## Build and Push Docker Image

### Linux/macOS

```bash
# Make script executable
chmod +x scripts/build-push.sh

# Run the build and push script
./scripts/build-push.sh
```

### Windows

```cmd
scripts\build-push.bat
```

The script will prompt you to:
1. Select registry type (Azure ACR or Docker Hub)
2. Enter registry credentials
3. Enter image tag (defaults to `latest`)

The script automatically sanitizes the image name to be Docker-compliant (lowercase, hyphens only).

---

## Azure AKS Setup

### 1. Install Prerequisites

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install kubectl
az aks install-cli

# Login to Azure
az login
```

### 2. Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="cargo-tracker-rg"
LOCATION="eastus"
ACR_NAME="cargotrackercr"
AKS_CLUSTER="cargo-tracker-aks"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

# Create AKS cluster (attach ACR for seamless image pulls)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --attach-acr $ACR_NAME \
  --enable-addons ingress-appgw \
  --appgw-name cargo-tracker-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --generate-ssh-keys

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER
```

### 3. Enable Azure Application Gateway Ingress Controller (AGIC)

```bash
# Verify AGIC addon is enabled
az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER \
  --query "addonProfiles.ingressApplicationGateway"
```

---

## Kubernetes Deployment

### 1. Deploy Using Script

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
- Full Docker image URI (e.g., `cargotrackercr.azurecr.io/cargo-tracker:latest`)
- Application configuration values (GRAPH_TRAVERSAL_URL, DB_JDBC_URL, etc.)

### 2. Manual Deployment

```bash
# Apply manifests in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# Verify resources
kubectl get pods,svc,ingress -n cargo-tracker
```

### 3. Kubernetes Manifest Descriptions

| File | Description |
|---|---|
| `namespace.yaml` | Creates `cargo-tracker` namespace |
| `deployment.yaml` | Deploys 2 replicas with resource limits and health probes |
| `service.yaml` | ClusterIP service exposing port 80 → 8080 |
| `ingress.yaml` | Azure Application Gateway ingress with cookie affinity |

---

## Configuration Management

### Environment Variables in Kubernetes

The deployment uses environment variables for configuration. Update `kubernetes/deployment.yaml` or use Kubernetes Secrets:

```bash
# Create a secret for database password
kubectl create secret generic cargo-tracker-secrets \
  --from-literal=db-password=YOUR_DB_PASSWORD \
  -n cargo-tracker
```

### Updating the Image

```bash
# Update deployment image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=cargotrackercr.azurecr.io/cargo-tracker:v2.0 \
  -n cargo-tracker

# Monitor rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

---

## Scaling and Management

### Horizontal Pod Autoscaling

```bash
# Enable HPA
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker

# Check HPA status
kubectl get hpa -n cargo-tracker
```

### Manual Scaling

```bash
kubectl scale deployment cargo-tracker --replicas=4 -n cargo-tracker
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=NEW_IMAGE_URI \
  -n cargo-tracker

# Check rollout status
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

# Describe a pod
kubectl describe pod <pod-name> -n cargo-tracker

# View pod logs
kubectl logs <pod-name> -n cargo-tracker

# Follow logs
kubectl logs -f deployment/cargo-tracker -n cargo-tracker

# Execute into pod
kubectl exec -it <pod-name> -n cargo-tracker -- /bin/bash
```

### Service Issues

```bash
# Check service endpoints
kubectl get endpoints -n cargo-tracker

# Describe service
kubectl describe service cargo-tracker-service -n cargo-tracker
```

### Ingress Issues

```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Check Application Gateway logs
az network application-gateway show \
  --resource-group $RESOURCE_GROUP \
  --name cargo-tracker-appgw
```

### Common Issues

| Issue | Solution |
|---|---|
| Pod in `CrashLoopBackOff` | Check logs: `kubectl logs <pod> -n cargo-tracker` |
| Pod in `Pending` state | Check node resources: `kubectl describe node` |
| Ingress not routing | Verify AGIC is running: `kubectl get pods -n kube-system` |
| Image pull error | Verify ACR attachment: `az aks check-acr --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --image $IMAGE` |
| JVM OOM errors | Increase memory limits in `deployment.yaml` |
| Slow startup | Increase `initialDelaySeconds` in liveness/readiness probes |

---

## Security Considerations

1. **Non-root container**: The application runs as a non-root `payara` user
2. **Secrets management**: Use Kubernetes Secrets for sensitive values (DB passwords)
3. **Network policies**: Consider adding NetworkPolicy resources to restrict pod communication
4. **Image scanning**: Enable ACR vulnerability scanning: `az acr task create ...`
5. **RBAC**: Use least-privilege service accounts for pods
6. **TLS**: Configure TLS termination at the Application Gateway level

```bash
# Add TLS to ingress
kubectl create secret tls cargo-tracker-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n cargo-tracker
```

---

## Java/Jakarta EE Specific Notes

### JVM Configuration

The application uses the following JVM flags (configurable via `JAVA_OPTS`):

```
-Xmx512m              # Maximum heap size
-Xms256m              # Initial heap size
-XX:+UseContainerSupport      # Enable container-aware JVM
-XX:MaxRAMPercentage=75.0     # Use 75% of container memory for heap
-XX:+UnlockExperimentalVMOptions
```

### Payara Micro

The application runs on **Payara Micro 6.2025.3** which provides:
- Jakarta EE 10 Full Platform support
- Embedded H2 database (for development)
- JMS messaging support
- CDI, JPA, JAX-RS, JSF support

### Database Configuration

- **Development**: H2 embedded file database (default)
- **Production**: PostgreSQL via `cloud` Maven profile

For production PostgreSQL:
```bash
# Build with PostgreSQL support
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://your-db-host:5432/cargotracker" \
  -DpostgreSqlUsername="dbuser" \
  -DpostgreSqlPassword="dbpassword"
```

### Health Checks

Since Payara Micro does not expose a standard `/health` endpoint by default, the Kubernetes probes use TCP socket checks on port 8080. For production, consider adding MicroProfile Health support to the application.

---

## Monitoring

```bash
# View resource usage
kubectl top pods -n cargo-tracker
kubectl top nodes

# View events
kubectl get events -n cargo-tracker --sort-by='.lastTimestamp'
```

---

## Cleanup

```bash
# Delete all resources in namespace
kubectl delete namespace cargo-tracker

# Or delete individual resources
kubectl delete -f kubernetes/ingress.yaml
kubectl delete -f kubernetes/service.yaml
kubectl delete -f kubernetes/deployment.yaml
kubectl delete -f kubernetes/namespace.yaml
```

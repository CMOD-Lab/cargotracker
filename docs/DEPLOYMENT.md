# Deployment Guide: cargo-tracker on Azure AKS

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to Azure Kubernetes Service (AKS). The application is a Jakarta EE 10 web application built with Maven, packaged as a WAR, and deployed on Payara Server.

- **Application**: Eclipse Cargo Tracker
- **Version**: 3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF/PrimeFaces, JMS, Batch)
- **Build Tool**: Maven 3.9.x
- **Java Version**: 11
- **Runtime**: Payara Server 6.2025.3
- **Package Type**: WAR
- **Application Port**: 8080 (HTTP), 8181 (HTTPS)
- **Target Platform**: Azure AKS

---

## Prerequisites

### Local Development Tools
- **Docker Desktop** 24.x or later
- **Java JDK 11** (Amazon Corretto 11 or Eclipse Temurin 11)
- **Apache Maven 3.9.x**
- **Git**

### Azure & Kubernetes Tools
- **Azure CLI** 2.50+ — [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **kubectl** 1.27+ — [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **Azure Subscription** with permissions to create AKS clusters and ACR registries

### Verify Prerequisites
```bash
docker --version
java -version
mvn --version
az --version
kubectl version --client
```

---

## Project Structure

```
cargotracker/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build descriptor
├── post-boot-commands.asadmin    # Payara post-boot configuration
├── src/
│   ├── main/
│   │   ├── java/                 # Application source code
│   │   ├── webapp/               # JSF/XHTML web resources
│   │   │   └── WEB-INF/
│   │   │       └── web.xml       # Web application descriptor
│   │   ├── resources/
│   │   │   └── META-INF/
│   │   │       └── persistence.xml
│   │   └── liberty/config/       # OpenLiberty server config
├── kubernetes/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
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
# Build WAR with default Payara profile (H2 database)
mvn clean package -DskipTests

# Build WAR with cloud profile (PostgreSQL)
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="yourpassword"
```

### 2. Build Docker Image Locally

```bash
docker build -t cargo-tracker:latest .
```

### 3. Run with Docker Compose

```bash
# Start the application
docker-compose up -d

# View logs
docker-compose logs -f cargo-tracker

# Stop the application
docker-compose down
```

Access the application at: **http://localhost:8080/cargo-tracker**

### 4. Environment Variables for Docker Compose

Create a `.env` file in the project root:

```env
DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource
DB_USER=
DB_PASSWORD=
GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
```

For PostgreSQL:
```env
DB_JDBC_URL=jdbc:postgresql://your-db-host:5432/cargotracker
DB_DRIVER_CLASS=org.postgresql.ds.PGPoolingDataSource
DB_USER=postgres
DB_PASSWORD=yourpassword
GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
```

---

## Build and Push Docker Image

### Using the Build Script (Linux/macOS)

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (defaults to `latest`)
2. Select registry type (Azure ACR or Docker Hub)
3. Provide registry credentials

### Using the Build Script (Windows)

```cmd
scripts\build-push.bat
```

### Manual Build and Push

**Azure ACR:**
```bash
# Login to ACR
az acr login --name <your-acr-name>

# Build and tag
docker build -t <your-acr-name>.azurecr.io/cargo-tracker:latest .

# Push
docker push <your-acr-name>.azurecr.io/cargo-tracker:latest
```

**Docker Hub:**
```bash
docker login
docker build -t <your-dockerhub-org>/cargo-tracker:latest .
docker push <your-dockerhub-org>/cargo-tracker:latest
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
  --name cargotrackercr \
  --sku Basic

# Enable admin access
az acr update --name cargotrackercr --admin-enabled true
```

### 4. Create AKS Cluster (if needed)

```bash
az aks create \
  --resource-group cargo-tracker-rg \
  --name cargo-tracker-aks \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --attach-acr cargotrackercr
```

### 5. Install Application Gateway Ingress Controller (AGIC)

```bash
# Enable AGIC add-on
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
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- Azure Resource Group name
- AKS Cluster name
- Full Docker image URI (e.g., `cargotrackercr.azurecr.io/cargo-tracker:latest`)
- Database connection details
- Graph traversal URL

### Using the Deploy Script (Windows)

```cmd
scripts\deploy-image.bat
```

### Manual Kubernetes Deployment

```bash
# 1. Update deployment.yaml with your image URI
sed -i 's|{{IMAGE_URI}}|cargotrackercr.azurecr.io/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:postgresql://your-db:5432/cargotracker|g' kubernetes/deployment.yaml
sed -i 's|{{DB_DRIVER_CLASS}}|org.postgresql.ds.PGPoolingDataSource|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}|postgres|g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|yourpassword|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml

# 2. Apply manifests in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# 3. Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# 4. Verify resources
kubectl get pods,svc,ingress -n cargo-tracker
```

---

## Kubernetes Manifest Descriptions

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
Defines the application deployment with:
- **2 replicas** for high availability
- **Resource limits**: CPU 500m, Memory 1Gi
- **Resource requests**: CPU 250m, Memory 512Mi
- **JVM options**: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`
- **TCP socket probes** on port 8080 (Payara does not expose a standard health endpoint by default)
- **Non-root user** security context

### service.yaml
Creates a `ClusterIP` service exposing:
- Port 80 → Container port 8080 (HTTP)
- Port 443 → Container port 8181 (HTTPS)

### ingress.yaml
Configures Azure Application Gateway Ingress Controller (AGIC) with:
- Host: `cargo-tracker.example.com` (update to your actual domain)
- Path: `/` (all traffic routed to the application)
- Request timeout: 120 seconds (appropriate for Jakarta EE startup)

---

## Configuration Management

### Updating the Ingress Host

Edit `kubernetes/ingress.yaml` and replace `cargo-tracker.example.com` with your actual domain:

```yaml
spec:
  rules:
    - host: your-actual-domain.com
```

### Using Kubernetes Secrets for Database Credentials

```bash
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=db-user=postgres \
  --from-literal=db-password=yourpassword \
  -n cargo-tracker
```

Then update `deployment.yaml` to reference the secret:
```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: cargo-tracker-db-secret
        key: db-user
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: cargo-tracker-db-secret
        key: db-password
```

### Using ConfigMaps for Non-Sensitive Configuration

```bash
kubectl create configmap cargo-tracker-config \
  --from-literal=graph-traversal-url="http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path" \
  -n cargo-tracker
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

# Check HPA status
kubectl get hpa -n cargo-tracker
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=cargotrackercr.azurecr.io/cargo-tracker:v2.0 \
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
kubectl describe pod <pod-name> -n cargo-tracker
kubectl logs <pod-name> -n cargo-tracker --previous
```
- Check JVM memory settings — increase memory limits if OOMKilled
- Verify database connection string is correct
- Ensure Payara Server starts successfully

#### Pods in Pending State
```bash
kubectl describe pod <pod-name> -n cargo-tracker
```
- Check node resource availability: `kubectl describe nodes`
- Verify resource requests are not too high for available nodes

#### Image Pull Errors
```bash
kubectl describe pod <pod-name> -n cargo-tracker | grep -A5 "Events"
```
- Verify ACR is attached to AKS: `az aks check-acr --name <aks-name> --resource-group <rg> --acr <acr-name>`
- Re-attach ACR: `az aks update --name <aks-name> --resource-group <rg> --attach-acr <acr-name>`

#### Ingress Not Working
```bash
kubectl get ingress -n cargo-tracker
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker
```
- Verify AGIC add-on is enabled: `az aks show --name <aks-name> --resource-group <rg> --query addonProfiles.ingressApplicationGateway`
- Check Application Gateway health in Azure Portal

#### Database Connection Issues
- Verify `DB_JDBC_URL` is correct and the database is accessible from AKS
- Check network security groups allow traffic from AKS subnet to database
- For Azure Database for PostgreSQL, ensure the AKS VNet is allowed

### Exec into a Running Pod

```bash
kubectl exec -it <pod-name> -n cargo-tracker -- /bin/bash
```

---

## Security Considerations

1. **Non-root container**: The application runs as a non-root user (`payara`) for security
2. **Secrets management**: Use Kubernetes Secrets or Azure Key Vault for sensitive data
3. **Network policies**: Consider adding Kubernetes NetworkPolicies to restrict pod-to-pod communication
4. **Image scanning**: Enable ACR vulnerability scanning: `az acr task create --registry <acr-name> --name scan --cmd "mcr.microsoft.com/acr/acr-task:latest" --file /dev/null`
5. **RBAC**: Use Kubernetes RBAC to limit access to the namespace
6. **TLS**: Configure TLS termination at the Application Gateway level
7. **Resource limits**: Always set resource limits to prevent resource exhaustion

---

## Java/Jakarta EE Specific Notes

### JVM Configuration
The deployment includes optimized JVM flags:
```
-Xmx512m -Xms256m
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:+UnlockExperimentalVMOptions
```

Adjust `-Xmx` and memory limits together. A good rule: set `-Xmx` to ~75% of the container memory limit.

### Payara Server Startup Time
Payara Server typically takes 60-120 seconds to start. The Kubernetes probes are configured with:
- `initialDelaySeconds: 120` for liveness probe
- `initialDelaySeconds: 90` for readiness probe

Adjust these values if your environment is slower.

### H2 vs PostgreSQL
- **Development**: Uses H2 embedded database (default Payara profile)
- **Production**: Use PostgreSQL with the `cloud` Maven profile
- The Docker image is built with the `cloud` profile to include the PostgreSQL JDBC driver

### JMS Queues
The application uses JMS queues (CargoHandledQueue, MisdirectedCargoQueue, etc.). These are configured internally within Payara Server's embedded messaging engine. No external message broker is required.

### Persistence
The application uses JPA with EclipseLink. Schema is auto-created on first startup (`jakarta.persistence.schema-generation.database.action=create`). For production, consider changing this to `none` and managing schema migrations separately.

---

## Useful Commands Reference

```bash
# Get all resources in namespace
kubectl get all -n cargo-tracker

# Port-forward for local testing
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker

# Delete all resources
kubectl delete namespace cargo-tracker

# Check resource usage
kubectl top pods -n cargo-tracker
kubectl top nodes
```

# Deployment Guide: cargo-tracker on GCP GKE

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to **Google Kubernetes Engine (GCP GKE)**. The application is a Jakarta EE 10 web application built with Maven, packaged as a WAR, and deployed on Payara Server.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF, JMS, Batch)
- **Build Tool**: Maven 3.9.x
- **Java Version**: 11
- **Runtime**: Payara Server 6.2025.3 (via amazoncorretto:11 base image)
- **Packaging**: WAR
- **Default Port**: 8080 (HTTP), 8181 (HTTPS)
- **Target Platform**: GCP GKE

---

## Prerequisites

### Local Development Tools
- **Docker** 20.10+ installed and running
- **Java 11** (Amazon Corretto or Eclipse Temurin)
- **Maven 3.9+**
- **kubectl** CLI installed
- **gcloud CLI** installed and authenticated

### GCP Requirements
- Active GCP project with billing enabled
- GKE cluster created (or permissions to create one)
- Google Artifact Registry API enabled (if using Artifact Registry)
- IAM permissions: `roles/container.developer`, `roles/artifactregistry.writer`

---

## Project Structure

```
dryrunRavi/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build descriptor
├── post-boot-commands.asadmin    # Payara post-boot configuration
├── src/
│   ├── main/
│   │   ├── java/                 # Application source code
│   │   ├── resources/            # Persistence, batch, SQL scripts
│   │   └── webapp/               # JSF pages, WEB-INF config
│   └── test/                     # Test sources
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # GKE Ingress (GCE)
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push
│   ├── build-push.bat            # Windows build & push
│   ├── deploy-image.sh           # Linux/macOS GKE deploy
│   └── deploy-image.bat          # Windows GKE deploy
└── docs/
    └── DEPLOYMENT.md             # This guide
```

---

## Local Development Setup

### 1. Build the Application Locally

```bash
# Build WAR using Maven (Payara profile is active by default)
mvn clean package -DskipTests -Ppayara

# Verify the WAR was created
ls -lh target/cargo-tracker.war
```

### 2. Build Docker Image Locally

```bash
# Build the Docker image
docker build -t cargo-tracker:latest .

# Verify the image
docker images | grep cargo-tracker
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

The application will be available at: **http://localhost:8080**

### 4. Environment Variables for Local Development

Create a `.env` file in the project root:

```env
DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource
DB_USER=
DB_PASSWORD=
GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
```

---

## Build and Push Docker Image

### Linux/macOS

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run the build and push script
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (defaults to `latest`)
2. Select registry type (Google Artifact Registry or Docker Hub)
3. Provide registry credentials

### Windows

```cmd
scripts\build-push.bat
```

### Manual Build and Push (Google Artifact Registry)

```bash
# Authenticate
gcloud auth login
gcloud config set project YOUR_GCP_PROJECT
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/cargo-tracker:latest .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/cargo-tracker:latest
```

---

## GCP GKE Prerequisites

### 1. Install and Configure gcloud CLI

```bash
# Install gcloud CLI (if not already installed)
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Set your project
gcloud config set project YOUR_GCP_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### 2. Create a GKE Cluster (if needed)

```bash
# Create a standard GKE cluster
gcloud container clusters create cargo-tracker-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type e2-standard-2 \
  --project YOUR_GCP_PROJECT_ID

# Get cluster credentials
gcloud container clusters get-credentials cargo-tracker-cluster \
  --zone us-central1-a \
  --project YOUR_GCP_PROJECT_ID
```

### 3. Create Artifact Registry Repository (if using GAR)

```bash
gcloud artifacts repositories create cargo-tracker-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="cargo-tracker Docker images"
```

---

## Kubernetes Deployment

### Manifest Descriptions

| File | Description |
|------|-------------|
| `kubernetes/namespace.yaml` | Creates the `cargo-tracker` namespace |
| `kubernetes/deployment.yaml` | Deploys 2 replicas of the application |
| `kubernetes/service.yaml` | ClusterIP service exposing ports 80 and 443 |
| `kubernetes/ingress.yaml` | GKE Ingress (GCE) for external HTTP access |

### Deploy Using Scripts

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
- GCP Project ID
- GCP Zone
- GKE Cluster Name
- Docker image URI (full path with tag)
- Optional environment variables (DB_JDBC_URL, DB_USER, DB_PASSWORD, etc.)

### Manual Deployment

```bash
# 1. Configure kubectl
gcloud container clusters get-credentials YOUR_CLUSTER \
  --zone YOUR_ZONE --project YOUR_PROJECT

# 2. Update deployment.yaml with your image URI
sed -i 's|{{IMAGE_URI}}|YOUR_IMAGE_URI|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|YOUR_DB_URL|g' kubernetes/deployment.yaml
sed -i 's|{{DB_DRIVER_CLASS}}|YOUR_DRIVER_CLASS|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}|YOUR_DB_USER|g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|YOUR_DB_PASSWORD|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|YOUR_GRAPH_URL|g' kubernetes/deployment.yaml

# 3. Apply manifests in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# 4. Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker

# 5. Verify
kubectl get pods,svc,ingress -n cargo-tracker
```

---

## Configuration Management

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_JDBC_URL` | JDBC URL for the database | H2 file-based |
| `DB_DRIVER_CLASS` | JDBC driver class | `org.h2.jdbcx.JdbcDataSource` |
| `DB_USER` | Database username | (empty) |
| `DB_PASSWORD` | Database password | (empty) |
| `GRAPH_TRAVERSAL_URL` | URL for the graph traversal REST service | localhost:8080 |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m ...` |
| `TZ` | Timezone | `UTC` |

### Production Database (PostgreSQL)

For production deployments, use the `cloud` Maven profile and configure PostgreSQL:

```bash
# Build with cloud profile
mvn clean package -DskipTests -Pcloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://YOUR_DB_HOST:5432/postgres" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="YOUR_PASSWORD"
```

Update Kubernetes environment variables accordingly:
```yaml
- name: DB_JDBC_URL
  value: "jdbc:postgresql://YOUR_DB_HOST:5432/postgres"
- name: DB_DRIVER_CLASS
  value: "org.postgresql.ds.PGPoolingDataSource"
- name: DB_USER
  value: "postgres"
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

---

## GKE Scaling and Management

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

### Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=NEW_IMAGE_URI \
  -n cargo-tracker

# Monitor rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# Rollback to specific revision
kubectl rollout undo deployment/cargo-tracker --to-revision=2 -n cargo-tracker

# View rollout history
kubectl rollout history deployment/cargo-tracker -n cargo-tracker
```

### Scale Manually

```bash
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker
```

---

## GKE-Specific Troubleshooting

### Pod Issues

```bash
# List pods
kubectl get pods -n cargo-tracker

# Describe a pod (shows events and errors)
kubectl describe pod POD_NAME -n cargo-tracker

# View pod logs
kubectl logs POD_NAME -n cargo-tracker

# Follow logs
kubectl logs -f deployment/cargo-tracker -n cargo-tracker

# Previous container logs (if pod restarted)
kubectl logs POD_NAME -n cargo-tracker --previous
```

### Service Issues

```bash
# Check service endpoints
kubectl get endpoints cargo-tracker-service -n cargo-tracker

# Test service connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://cargo-tracker-service.cargo-tracker.svc.cluster.local/
```

### Ingress Issues

```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Check GKE ingress controller events
kubectl get events -n cargo-tracker --sort-by='.lastTimestamp'
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Pod in `CrashLoopBackOff` | Application startup failure | Check logs: `kubectl logs POD_NAME -n cargo-tracker` |
| Pod in `Pending` | Insufficient cluster resources | Scale cluster or reduce resource requests |
| Ingress IP not assigned | GCE ingress provisioning | Wait 5-10 minutes; check GCP Console |
| `ImagePullBackOff` | Cannot pull image | Verify image URI and registry credentials |
| JVM OOM errors | Insufficient memory limits | Increase memory limits in deployment.yaml |
| Payara startup timeout | Slow JVM startup | Increase `initialDelaySeconds` in probes |

---

## Security Considerations

1. **Non-root user**: The container runs as the `payara` user (non-root)
2. **Secrets management**: Use Kubernetes Secrets for sensitive values (DB passwords, API keys)
3. **Network policies**: Consider adding NetworkPolicy resources to restrict pod-to-pod communication
4. **Image scanning**: Scan Docker images with `gcloud artifacts docker images scan`
5. **RBAC**: Apply least-privilege RBAC policies for service accounts
6. **TLS**: Configure GKE Managed Certificates for HTTPS via the ingress annotations

### Creating Kubernetes Secrets

```bash
kubectl create secret generic cargo-tracker-secrets \
  --from-literal=db-password=YOUR_DB_PASSWORD \
  -n cargo-tracker
```

---

## Java/Jakarta EE Specific Notes

- **JVM Memory**: Configured with `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`
- **Container Awareness**: `-XX:+UseContainerSupport` ensures JVM respects container memory limits
- **Payara Startup**: Payara Server takes 60-90 seconds to start; probes are configured with appropriate delays
- **H2 Database**: Default embedded H2 database is suitable for development only; use PostgreSQL for production
- **JMS Queues**: The application uses JMS queues (CargoHandledQueue, MisdirectedCargoQueue, etc.) which are configured in Payara
- **Persistence**: JPA with EclipseLink; schema is auto-created on first startup
- **Profiles**: Use `-Ppayara` (default), `-Pglassfish`, `-Pcloud`, or `-Popenliberty` Maven profiles

---

## Quick Reference

```bash
# Build image
docker build -t cargo-tracker:latest .

# Run locally
docker-compose up -d

# Build and push to registry
./scripts/build-push.sh

# Deploy to GKE
./scripts/deploy-image.sh

# Check deployment status
kubectl get pods,svc,ingress -n cargo-tracker

# View logs
kubectl logs -f deployment/cargo-tracker -n cargo-tracker

# Rollback
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
```

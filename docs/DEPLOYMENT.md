# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment process for the **Eclipse Cargo Tracker** application on **Google Kubernetes Engine (GKE)**. The application is a Jakarta EE 10 web application built with Maven, packaged as a WAR, and deployed on Payara Micro.

---

## Technology Stack

| Component         | Details                                      |
|-------------------|----------------------------------------------|
| Framework         | Jakarta EE 10 (CDI, JPA, JAX-RS, JSF, JMS)  |
| Application Server| Payara Micro 6.2025.3                        |
| Build Tool        | Maven 3.9.x                                  |
| Java Version      | Java 11                                      |
| Package Type      | WAR                                          |
| Base Image        | amazoncorretto:11                            |
| Database          | PostgreSQL (production) / H2 (development)   |
| Application Port  | 8080                                         |
| Health Endpoint   | `/rest/health`                               |

---

## Prerequisites

### Local Development
- Java 11 JDK (Amazon Corretto 11 recommended)
- Maven 3.9.x
- Docker Desktop (latest)
- Git

### GCP GKE Deployment
- [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install) installed and authenticated
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- GCP Project with billing enabled
- GKE cluster created (see GKE Setup section)
- Google Artifact Registry or Docker Hub account

---

## Local Development Setup

### 1. Clone and Build (Default H2 Profile)

```bash
# Clone the repository
git clone <repository-url>
cd BackendServices

# Build with default Payara profile (uses H2 in-memory database)
mvn clean package -DskipTests

# Run with Payara Micro locally
java -jar ~/.m2/repository/fish/payara/extras/payara-micro/6.2025.3/payara-micro-6.2025.3.jar \
     --deploy target/cargo-tracker.war \
     --port 8080
```

Access the application at: http://localhost:8080/

### 2. Build with PostgreSQL (Cloud Profile)

```bash
mvn clean package -Pcloud -DskipTests \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/postgres" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"
```

---

## Docker Local Deployment

### 1. Build Docker Image

```bash
# From the project root directory
docker build -t cargo-tracker:latest .
```

### 2. Run with Docker Compose

```bash
# Set environment variables for your PostgreSQL instance
export DB_HOST=your-postgres-host
export DB_PORT=5432
export DB_NAME=postgres
export DB_USER=postgres
export DB_PASSWORD=your-password

# Start the application
docker-compose up -d

# View logs
docker-compose logs -f cargo-tracker
```

### 3. Verify Local Docker Deployment

```bash
# Check health endpoint
curl http://localhost:8080/rest/health

# Expected response:
# {"status":"UP","timestamp":"...","application":"cargo-tracker"}
```

---

## Build and Push Docker Image

### Using build-push.sh (Linux/macOS)

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will prompt you to:
1. Select registry type (Google Artifact Registry or Docker Hub)
2. Enter registry credentials and details
3. Specify an image tag (defaults to `latest`)

### Using build-push.bat (Windows)

```cmd
scripts\build-push.bat
```

### Manual Build and Push (Google Artifact Registry)

```bash
# Authenticate
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build
docker build -t us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest .

# Push
docker push us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest
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
gcloud config set project YOUR_PROJECT_ID
```

### 2. Enable Required APIs

```bash
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3. Create GKE Cluster

```bash
# Create a standard GKE cluster
gcloud container clusters create cargo-tracker-cluster \
    --zone us-central1-a \
    --num-nodes 3 \
    --machine-type e2-standard-2 \
    --enable-autoscaling \
    --min-nodes 2 \
    --max-nodes 5

# OR create an Autopilot cluster (recommended for production)
gcloud container clusters create-auto cargo-tracker-cluster \
    --region us-central1
```

### 4. Configure kubectl

```bash
gcloud container clusters get-credentials cargo-tracker-cluster \
    --zone us-central1-a \
    --project YOUR_PROJECT_ID

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

### 5. Create Artifact Registry Repository

```bash
gcloud artifacts repositories create my-repo \
    --repository-format=docker \
    --location=us-central1 \
    --description="Cargo Tracker Docker images"
```

---

## Kubernetes Deployment

### Manifest Files Overview

| File                          | Description                                      |
|-------------------------------|--------------------------------------------------|
| `kubernetes/namespace.yaml`   | Creates `cargo-tracker` namespace                |
| `kubernetes/deployment.yaml`  | Deploys 2 replicas of the application            |
| `kubernetes/service.yaml`     | ClusterIP service exposing port 80 → 8080        |
| `kubernetes/ingress.yaml`     | GCE Ingress for external HTTP access             |

### Deploy Using Script (Recommended)

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- GCP Project ID
- GCP Zone
- GKE Cluster Name
- Docker image URI (full path with tag)
- Database connection details (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)
- Graph traversal URL

### Manual Deployment

```bash
# 1. Update deployment.yaml with your image URI
sed -i 's|{{IMAGE_URI}}|us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{DB_HOST}}|10.0.0.1|g' kubernetes/deployment.yaml
sed -i 's|{{DB_PORT}}|5432|g' kubernetes/deployment.yaml
sed -i 's|{{DB_NAME}}|postgres|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}|postgres|g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}|your-password|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://cargo-tracker-service/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml

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

## Configuration Management

### Environment Variables

| Variable              | Description                                    | Default                                              |
|-----------------------|------------------------------------------------|------------------------------------------------------|
| `JAVA_OPTS`           | JVM options                                    | `-Xmx512m -Xms256m -XX:+UseContainerSupport`        |
| `TZ`                  | Timezone                                       | `UTC`                                                |
| `DB_HOST`             | PostgreSQL host                                | `localhost`                                          |
| `DB_PORT`             | PostgreSQL port                                | `5432`                                               |
| `DB_NAME`             | PostgreSQL database name                       | `postgres`                                           |
| `DB_USER`             | PostgreSQL username                            | `postgres`                                           |
| `DB_PASSWORD`         | PostgreSQL password                            | `postgres`                                           |
| `GRAPH_TRAVERSAL_URL` | URL for graph traversal REST service           | `http://localhost:8080/rest/graph-traversal/...`     |

### Using Kubernetes Secrets for Sensitive Data

```bash
# Create a secret for database credentials
kubectl create secret generic cargo-tracker-db-secret \
    --from-literal=DB_USER=postgres \
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

## GKE Scaling and Management

### Horizontal Pod Autoscaling

```bash
# Enable HPA based on CPU utilization
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
# Update image to new version
kubectl set image deployment/cargo-tracker \
    cargo-tracker=us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:v2.0 \
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
kubectl describe pod <pod-name> -n cargo-tracker

# View pod logs
kubectl logs <pod-name> -n cargo-tracker --tail=200

# View previous container logs (if crashed)
kubectl logs <pod-name> -n cargo-tracker --previous
```

### Health Check Failures

The application exposes a health endpoint at `/rest/health`. If health checks fail:

```bash
# Port-forward to test locally
kubectl port-forward deployment/cargo-tracker 8080:8080 -n cargo-tracker

# Test health endpoint
curl http://localhost:8080/rest/health
# Expected: {"status":"UP","timestamp":"...","application":"cargo-tracker"}
```

**Common causes:**
- JVM startup time: Payara Micro takes 60-90 seconds to start. The `initialDelaySeconds: 90` in liveness probe accounts for this.
- Database connectivity: Verify `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` are correct.
- Insufficient memory: Increase memory limits if OOMKilled.

### Ingress Not Getting External IP

```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# GCE Ingress may take 5-10 minutes to provision
kubectl get ingress -n cargo-tracker -w
```

### Database Connection Issues

```bash
# Test database connectivity from within a pod
kubectl exec -it <pod-name> -n cargo-tracker -- \
    sh -c "nc -zv $DB_HOST $DB_PORT"
```

### Image Pull Errors

```bash
# Check if image exists in registry
gcloud artifacts docker images list us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO

# Verify GKE has access to Artifact Registry
gcloud projects add-iam-policy-binding MY_PROJECT \
    --member="serviceAccount:$(gcloud container clusters describe cargo-tracker-cluster \
        --zone us-central1-a --format='value(nodeConfig.serviceAccount)')" \
    --role="roles/artifactregistry.reader"
```

---

## Security Considerations

1. **Non-root container**: The application runs as the `payara` user (non-root) inside the container.
2. **Secrets management**: Use Kubernetes Secrets or GCP Secret Manager for sensitive values (DB passwords, API keys).
3. **Network policies**: Consider adding Kubernetes NetworkPolicy to restrict pod-to-pod communication.
4. **HTTPS**: Configure GKE Managed Certificates for TLS termination at the Ingress level.
5. **Image scanning**: Enable Artifact Registry vulnerability scanning for container images.
6. **Resource limits**: CPU and memory limits are set to prevent resource exhaustion.

### Enable HTTPS with GKE Managed Certificates

```bash
# Create a static IP
gcloud compute addresses create cargo-tracker-ip --global

# Create managed certificate (update ingress.yaml annotations)
# networking.gke.io/managed-certificates: "cargo-tracker-cert"
kubectl apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: cargo-tracker-cert
  namespace: cargo-tracker
spec:
  domains:
    - cargo-tracker.example.com
EOF
```

---

## Java-Specific Notes

### JVM Configuration

The application uses the following JVM flags optimized for containers:
- `-XX:+UseContainerSupport`: Enables JVM container awareness (reads cgroup limits)
- `-XX:MaxRAMPercentage=75.0`: Uses 75% of container memory for heap
- `-Xmx512m -Xms256m`: Explicit heap bounds as fallback
- `-XX:+UnlockExperimentalVMOptions`: Enables experimental JVM features

### Payara Micro Startup Time

Payara Micro with Jakarta EE features (CDI, JPA, JMS, JSF) typically takes **60-120 seconds** to fully start. The Kubernetes probes are configured with:
- `initialDelaySeconds: 90` for liveness probe
- `initialDelaySeconds: 60` for readiness probe

Adjust these values based on observed startup times in your environment.

### Jakarta EE Profiles

The application supports multiple Maven profiles:
- `payara` (default): H2 file-based database, suitable for development
- `cloud`: PostgreSQL database, suitable for production/GKE deployment
- `glassfish`: GlassFish server with H2
- `openliberty`: OpenLiberty server with HSQLDB

For GKE deployment, the `cloud` profile is used in the Dockerfile.

---

## Quick Reference

```bash
# Build and push image
./scripts/build-push.sh

# Deploy to GKE
./scripts/deploy-image.sh

# Check deployment status
kubectl get pods,svc,ingress -n cargo-tracker

# View application logs
kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=100 -f

# Scale deployment
kubectl scale deployment/cargo-tracker --replicas=3 -n cargo-tracker

# Rollback
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# Delete all resources
kubectl delete namespace cargo-tracker
```

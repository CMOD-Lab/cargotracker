# Eclipse Cargo Tracker - GCP GKE Deployment Guide

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to **Google Kubernetes Engine (GKE)**. The application is a Jakarta EE 10 reference implementation demonstrating Domain-Driven Design (DDD) patterns, packaged as a WAR and deployed on **Payara Micro**.

---

## Application Details

| Property | Value |
|---|---|
| Application Name | cargo-tracker |
| Framework | Jakarta EE 10 (Payara Micro) |
| Java Version | 11 |
| Package Type | WAR |
| Application Port | 8080 (HTTP) |
| Management Port | 8081 (HTTPS) |
| Health Endpoint | `/rest/health` |
| Context Root | `/` |
| Build Tool | Maven |

---

## Prerequisites

### Local Development Tools
- **Docker** 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Java 11** (Amazon Corretto 11 or Eclipse Temurin 11)
- **Maven 3.9+** ([Install Maven](https://maven.apache.org/install.html))

### GCP / GKE Tools
- **Google Cloud SDK (gcloud)** ([Install gcloud](https://cloud.google.com/sdk/docs/install))
- **kubectl** ([Install kubectl](https://kubernetes.io/docs/tasks/tools/))
- A **GCP Project** with billing enabled
- **GKE API** and **Artifact Registry API** enabled

### GCP APIs to Enable
```bash
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

---

## 1. Local Development Setup

### 1.1 Build the Application Locally

```bash
# Clone the repository
cd BackendServices

# Build with Maven (Payara profile - default)
mvn clean package -DskipTests -P payara

# Verify WAR is created
ls -lh target/cargo-tracker.war
```

### 1.2 Run with Docker Compose (Local)

```bash
# Build and start the application container
docker-compose up --build

# Access the application
open http://localhost:8080

# Check health endpoint
curl http://localhost:8080/rest/health

# Stop the application
docker-compose down
```

### 1.3 Environment Variables for Local Development

Create a `.env` file in the project root (never commit this file):

```env
# Database (H2 default - no changes needed for local dev)
DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
DB_USER=
DB_PASSWORD=

# Graph Traversal URL (internal service)
GRAPH_TRAVERSAL_URL=http://localhost:8080/rest/graph-traversal/shortest-path
```

---

## 2. Build and Push Docker Image

### 2.1 Using the Build Script (Linux/macOS)

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run the build and push script
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type (Google Artifact Registry or Docker Hub)
3. Provide registry credentials

### 2.2 Using the Build Script (Windows)

```cmd
scripts\build-push.bat
```

### 2.3 Manual Build and Push (Google Artifact Registry)

```bash
# Set variables
GCP_PROJECT="your-gcp-project-id"
GCP_REGION="us-central1"
AR_REPO="cargo-tracker"
IMAGE_TAG="latest"

# Authenticate
gcloud auth login
gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev

# Create Artifact Registry repository (first time only)
gcloud artifacts repositories create ${AR_REPO} \
  --repository-format=docker \
  --location=${GCP_REGION} \
  --description="Cargo Tracker Docker images"

# Build and push
docker build -t ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}/cargo-tracker:${IMAGE_TAG} .
docker push ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}/cargo-tracker:${IMAGE_TAG}
```

---

## 3. GCP GKE Setup

### 3.1 Create a GKE Cluster

```bash
# Set your project
gcloud config set project YOUR_GCP_PROJECT_ID

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

### 3.2 Configure kubectl

```bash
gcloud container clusters get-credentials cargo-tracker-cluster \
  --zone us-central1-a \
  --project YOUR_GCP_PROJECT_ID

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

## 4. Kubernetes Deployment

### 4.1 Using the Deploy Script (Linux/macOS)

```bash
# Make the script executable
chmod +x scripts/deploy-image.sh

# Run the deployment script
./scripts/deploy-image.sh
```

The script will prompt for:
- GCP Project ID
- GCP Zone
- GKE Cluster Name
- Docker Image URI (full path with tag)
- Optional environment variables (DB_JDBC_URL, DB_USER, DB_PASSWORD, GRAPH_TRAVERSAL_URL)

### 4.2 Using the Deploy Script (Windows)

```cmd
scripts\deploy-image.bat
```

### 4.3 Manual Kubernetes Deployment

```bash
# Set your image URI
IMAGE_URI="us-central1-docker.pkg.dev/YOUR_PROJECT/cargo-tracker/cargo-tracker:latest"

# Update deployment.yaml with actual image
sed -i 's|{{IMAGE_URI}}|'"${IMAGE_URI}"'|g' kubernetes/deployment.yaml

# Update environment variable placeholders
sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}||g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}||g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml

# Apply manifests in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s

# Verify resources
kubectl get pods,svc,ingress -n cargo-tracker
```

### 4.4 Kubernetes Manifest Descriptions

| File | Description |
|---|---|
| `kubernetes/namespace.yaml` | Creates the `cargo-tracker` namespace |
| `kubernetes/deployment.yaml` | Deploys 2 replicas of the Payara Micro container |
| `kubernetes/service.yaml` | ClusterIP service exposing port 80 → 8080 |
| `kubernetes/ingress.yaml` | GCE Ingress for external HTTP access |

---

## 5. PostgreSQL Database (Cloud/Production)

For production deployments, use PostgreSQL instead of the embedded H2 database.

### 5.1 Build with PostgreSQL Profile

```bash
mvn clean package -DskipTests -P cloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://YOUR_DB_HOST:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="your-password"
```

### 5.2 Configure PostgreSQL in Kubernetes

Update the environment variables in `kubernetes/deployment.yaml`:

```yaml
- name: DB_JDBC_URL
  value: "jdbc:postgresql://YOUR_POSTGRES_HOST:5432/cargotracker"
- name: DB_USER
  value: "postgres"
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: cargo-tracker-db-secret
      key: password
```

### 5.3 Create Kubernetes Secret for DB Password

```bash
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=password=YOUR_DB_PASSWORD \
  -n cargo-tracker
```

---

## 6. Configuration Management

### 6.1 Environment Variables Reference

| Variable | Description | Default |
|---|---|---|
| `JAVA_OPTS` | JVM options | `-Xms256m -Xmx512m -XX:+UseContainerSupport` |
| `TZ` | Timezone | `UTC` |
| `DB_JDBC_URL` | JDBC connection URL | H2 file-based |
| `DB_USER` | Database username | (empty) |
| `DB_PASSWORD` | Database password | (empty) |
| `GRAPH_TRAVERSAL_URL` | Graph traversal service URL | localhost |

### 6.2 JVM Tuning for Containers

The application uses container-aware JVM settings:
- `-XX:+UseContainerSupport` - Enables container memory awareness
- `-XX:MaxRAMPercentage=75.0` - Uses 75% of container memory for heap
- `-Xms256m -Xmx512m` - Explicit heap bounds (override with JAVA_OPTS)

---

## 7. Health Checks

The application exposes a custom health endpoint:

```
GET /rest/health
```

**Response:**
```json
{"status":"UP","application":"cargo-tracker"}
```

Kubernetes probes are configured in `deployment.yaml`:
- **Liveness Probe**: `GET /rest/health` - starts after 120s, checks every 30s
- **Readiness Probe**: `GET /rest/health` - starts after 90s, checks every 15s

> **Note**: Payara Micro requires extended startup time (90-120 seconds). The probe delays are set accordingly.

---

## 8. Scaling and Management

### 8.1 Manual Scaling

```bash
# Scale to 3 replicas
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker

# Check scaling status
kubectl get pods -n cargo-tracker
```

### 8.2 Horizontal Pod Autoscaler (HPA)

```bash
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker

kubectl get hpa -n cargo-tracker
```

### 8.3 Rolling Updates

```bash
# Update image
kubectl set image deployment/cargo-tracker \
  cargo-tracker=NEW_IMAGE_URI \
  -n cargo-tracker

# Monitor rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

### 8.4 Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

# Rollback to specific revision
kubectl rollout history deployment/cargo-tracker -n cargo-tracker
kubectl rollout undo deployment/cargo-tracker --to-revision=2 -n cargo-tracker
```

---

## 9. Troubleshooting

### 9.1 Pod Not Starting

```bash
# Check pod status
kubectl get pods -n cargo-tracker

# Describe pod for events
kubectl describe pod -l app=cargo-tracker -n cargo-tracker

# Check pod logs
kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=200

# Check previous container logs (if crashed)
kubectl logs -l app=cargo-tracker -n cargo-tracker --previous
```

### 9.2 Common Issues

**Issue: Pod stuck in `Pending` state**
```bash
# Check node resources
kubectl describe nodes
kubectl get events -n cargo-tracker --sort-by='.lastTimestamp'
```

**Issue: Pod in `CrashLoopBackOff`**
```bash
# Check logs for startup errors
kubectl logs -l app=cargo-tracker -n cargo-tracker --previous

# Common causes:
# - Payara Micro startup timeout (increase initialDelaySeconds)
# - Database connection failure (check DB_JDBC_URL)
# - Insufficient memory (increase memory limits)
```

**Issue: Health probe failing**
```bash
# Test health endpoint from within the cluster
kubectl exec -it $(kubectl get pod -l app=cargo-tracker -n cargo-tracker -o jsonpath='{.items[0].metadata.name}') \
  -n cargo-tracker -- \
  java -cp /opt/payara/payara-micro.jar fish.payara.micro.PayaraMicro --help

# Check if application is listening on port 8080
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
curl http://localhost:8080/rest/health
```

**Issue: Ingress not routing traffic**
```bash
# Check ingress status
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Check GCE load balancer
gcloud compute forwarding-rules list
gcloud compute backend-services list
```

### 9.3 Resource Issues

```bash
# Check resource usage
kubectl top pods -n cargo-tracker
kubectl top nodes

# Increase memory if OOMKilled
# Edit deployment.yaml: increase limits.memory to "2Gi"
kubectl edit deployment cargo-tracker -n cargo-tracker
```

---

## 10. Security Considerations

1. **Non-root container**: The application runs as user `payara` (UID 1000)
2. **Secrets management**: Use Kubernetes Secrets or GCP Secret Manager for passwords
3. **Network policies**: Consider adding NetworkPolicy to restrict pod-to-pod communication
4. **Image scanning**: Enable Artifact Registry vulnerability scanning
5. **Workload Identity**: Use GKE Workload Identity for GCP service authentication

### 10.1 Using GCP Secret Manager

```bash
# Create a secret
gcloud secrets create cargo-tracker-db-password \
  --data-file=- <<< "your-db-password"

# Grant GKE service account access
gcloud secrets add-iam-policy-binding cargo-tracker-db-password \
  --member="serviceAccount:YOUR_GSA@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 11. Jakarta EE / Payara Micro Notes

- **Startup Time**: Payara Micro typically takes 60-120 seconds to fully start. Kubernetes probes are configured with appropriate delays.
- **JMS Queues**: The application uses internal JMS queues (CargoHandledQueue, MisdirectedCargoQueue, etc.). These are managed by Payara Micro's embedded messaging engine.
- **H2 Database**: The default H2 file-based database is suitable for development only. Use PostgreSQL for production.
- **Context Root**: The application is deployed at `/` (root context) in the Docker/Kubernetes setup.
- **REST API**: Available at `/rest/*` (e.g., `/rest/health`, `/rest/graph-traversal/shortest-path`)
- **Web UI**: Available at the root path `/`

---

## 12. Quick Reference Commands

```bash
# View all resources in namespace
kubectl get all -n cargo-tracker

# Stream logs
kubectl logs -f -l app=cargo-tracker -n cargo-tracker

# Execute shell in pod
kubectl exec -it $(kubectl get pod -l app=cargo-tracker -n cargo-tracker -o jsonpath='{.items[0].metadata.name}') -n cargo-tracker -- /bin/bash

# Delete all resources
kubectl delete namespace cargo-tracker

# Restart deployment (rolling restart)
kubectl rollout restart deployment/cargo-tracker -n cargo-tracker
```

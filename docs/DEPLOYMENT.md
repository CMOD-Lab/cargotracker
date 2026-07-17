# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers building, containerizing, and deploying the **Eclipse Cargo Tracker** application to **Google Kubernetes Engine (GKE)**. The application is a Jakarta EE 10 web application running on **Payara Micro**, packaged as a WAR file.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Local Development with Docker Compose](#local-development-with-docker-compose)
4. [Build and Push Docker Image](#build-and-push-docker-image)
5. [GCP GKE Prerequisites](#gcp-gke-prerequisites)
6. [GKE Cluster Setup](#gke-cluster-setup)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Configuration Management](#configuration-management)
9. [Scaling and Management](#scaling-and-management)
10. [Troubleshooting](#troubleshooting)
11. [Security Considerations](#security-considerations)
12. [Technology-Specific Notes](#technology-specific-notes)

---

## Prerequisites

### Local Development
- **Java 11** (Amazon Corretto 11 or Eclipse Temurin 11)
- **Maven 3.9+**
- **Docker 24+** and **Docker Compose v2**
- **Git**

### Cloud Deployment
- **Google Cloud SDK (gcloud CLI)** - [Install Guide](https://cloud.google.com/sdk/docs/install)
- **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **GCP Project** with billing enabled
- **GKE API** enabled in your GCP project

---

## Project Structure

```
dryrun1/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build descriptor
├── post-boot-commands.asadmin    # Payara post-boot configuration
├── src/                          # Application source code
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # GKE Ingress (HTTP/HTTPS)
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push script
│   ├── build-push.bat            # Windows build & push script
│   ├── deploy-image.sh           # Linux/macOS GKE deploy script
│   └── deploy-image.bat          # Windows GKE deploy script
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development with Docker Compose

### 1. Build and Start

```bash
# From the project root directory
docker compose up --build
```

### 2. Access the Application

- **Application**: http://localhost:8080/
- **Booking Interface**: http://localhost:8080/booking/
- **Event Logger**: http://localhost:8080/event-logger/
- **REST API**: http://localhost:8080/rest/

### 3. Stop the Application

```bash
docker compose down
# To also remove volumes:
docker compose down -v
```

### 4. Environment Variables (docker-compose.yml)

| Variable | Default | Description |
|---|---|---|
| `TZ` | `UTC` | Container timezone |
| `JAVA_OPTS` | JVM flags | JVM memory and container settings |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/rest/graph-traversal/shortest-path` | Pathfinder service URL |

---

## Build and Push Docker Image

### Linux / macOS

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

### Windows

```cmd
scripts\build-push.bat
```

### Script Prompts

The script will ask for:
1. **Image tag** (default: `latest`)
2. **Registry type**: Google Artifact Registry or Docker Hub
3. **Registry credentials** based on selection

### Manual Build

```bash
# Build image
docker build -t cargo-tracker:latest .

# Tag for Artifact Registry
docker tag cargo-tracker:latest us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest

# Push
docker push us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest
```

---

## GCP GKE Prerequisites

### 1. Install and Configure gcloud CLI

```bash
# Authenticate
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### 2. Create Artifact Registry Repository

```bash
gcloud artifacts repositories create cargo-tracker \
    --repository-format=docker \
    --location=us-central1 \
    --description="Cargo Tracker Docker images"
```

### 3. Configure Docker Authentication

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

---

## GKE Cluster Setup

### 1. Create a GKE Cluster

```bash
gcloud container clusters create cargo-tracker-cluster \
    --zone us-central1-a \
    --num-nodes 3 \
    --machine-type e2-standard-2 \
    --enable-autoscaling \
    --min-nodes 2 \
    --max-nodes 5
```

### 2. Configure kubectl

```bash
gcloud container clusters get-credentials cargo-tracker-cluster \
    --zone us-central1-a \
    --project YOUR_PROJECT_ID
```

### 3. Verify Connectivity

```bash
kubectl cluster-info
kubectl get nodes
```

---

## Kubernetes Deployment

### Automated Deployment (Recommended)

#### Linux / macOS

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
- Docker image URI
- Optional environment variable values

### Manual Deployment

```bash
# 1. Apply namespace
kubectl apply -f kubernetes/namespace.yaml

# 2. Update image URI in deployment.yaml
sed -i 's|{{IMAGE_URI}}|us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest|g' kubernetes/deployment.yaml

# 3. Update environment variable placeholders
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}||g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}||g' kubernetes/deployment.yaml

# 4. Apply manifests
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

# 5. Wait for rollout
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n cargo-tracker

# Check services
kubectl get svc -n cargo-tracker

# Check ingress
kubectl get ingress -n cargo-tracker

# View logs
kubectl logs -f deployment/cargo-tracker -n cargo-tracker
```

---

## Configuration Management

### Environment Variables

The following environment variables can be configured in `kubernetes/deployment.yaml`:

| Variable | Description | Default |
|---|---|---|
| `TZ` | Container timezone | `UTC` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m ...` |
| `GRAPH_TRAVERSAL_URL` | Pathfinder REST endpoint | `http://localhost:8080/rest/...` |
| `DB_JDBC_URL` | JDBC connection URL | H2 file-based |
| `DB_USER` | Database username | (empty) |
| `DB_PASSWORD` | Database password | (empty) |

### Using Kubernetes Secrets for Sensitive Data

```bash
# Create secret for database credentials
kubectl create secret generic cargo-tracker-db-secret \
    --from-literal=db-user=myuser \
    --from-literal=db-password=mypassword \
    -n cargo-tracker
```

Then reference in deployment.yaml:
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

### Using PostgreSQL in Production (Cloud Profile)

Build with the cloud Maven profile for PostgreSQL support:

```bash
mvn clean package -Pcloud \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://HOST:5432/postgres" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"
```

---

## Scaling and Management

### Manual Scaling

```bash
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker
```

### Horizontal Pod Autoscaler (HPA)

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
kubectl describe pod -l app=cargo-tracker -n cargo-tracker

# Check events
kubectl get events -n cargo-tracker --sort-by='.lastTimestamp'

# Check logs
kubectl logs -l app=cargo-tracker -n cargo-tracker --previous
```

### Common Issues

#### 1. ImagePullBackOff
- Verify the image URI is correct
- Ensure GKE has access to the registry:
  ```bash
  gcloud projects add-iam-policy-binding MY_PROJECT \
      --member="serviceAccount:MY_SA@MY_PROJECT.iam.gserviceaccount.com" \
      --role="roles/artifactregistry.reader"
  ```

#### 2. CrashLoopBackOff
- Check application logs: `kubectl logs -f deployment/cargo-tracker -n cargo-tracker`
- Payara Micro startup can take 60-90 seconds; verify probe `initialDelaySeconds` is sufficient
- Check JVM memory: ensure container memory limits are at least 512Mi

#### 3. Ingress Not Getting IP
- GKE Ingress provisioning can take 5-10 minutes
- Check ingress status: `kubectl describe ingress cargo-tracker-ingress -n cargo-tracker`
- Ensure the GKE cluster has HTTP load balancing enabled

#### 4. Application Returns 404
- Verify the context root is `/` (set in Payara Micro startup command)
- Check Payara Micro deployment logs for WAR deployment errors

#### 5. Out of Memory
- Increase memory limits in `kubernetes/deployment.yaml`
- Adjust `JAVA_OPTS`: `-Xmx768m -Xms256m`

### Useful Debug Commands

```bash
# Execute shell in running pod
kubectl exec -it $(kubectl get pod -l app=cargo-tracker -n cargo-tracker -o jsonpath='{.items[0].metadata.name}') \
    -n cargo-tracker -- /bin/bash

# Port-forward for local access
kubectl port-forward deployment/cargo-tracker 8080:8080 -n cargo-tracker

# Check resource usage
kubectl top pods -n cargo-tracker
```

---

## Security Considerations

1. **Non-root user**: The container runs as the `payara` user (non-root)
2. **Secrets management**: Use Kubernetes Secrets for database credentials, never hardcode in manifests
3. **Network policies**: Consider adding NetworkPolicy resources to restrict pod-to-pod communication
4. **Image scanning**: Scan Docker images with tools like Trivy or GCP Container Analysis
5. **RBAC**: Apply least-privilege RBAC policies for the service account
6. **TLS**: Configure GKE Managed Certificates for HTTPS in production:
   ```bash
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

## Technology-Specific Notes

### Jakarta EE 10 / Payara Micro

- **Startup time**: Payara Micro typically takes 30-90 seconds to start. The Kubernetes probes are configured with `initialDelaySeconds: 60` (readiness) and `initialDelaySeconds: 90` (liveness) to accommodate this.
- **Context root**: The application is deployed at `/` (root context) via the `--contextroot /` flag in the Payara Micro startup command.
- **JMS Queues**: The application uses JMS queues (CargoHandledQueue, MisdirectedCargoQueue, etc.) which are managed internally by Payara Micro.
- **H2 Database**: The default profile uses H2 file-based database stored in `/opt/payara/cargo-tracker-data/`. For production, use the `cloud` Maven profile with PostgreSQL.
- **Clustering**: The `--nocluster` flag is used in the Dockerfile to disable Payara clustering (not needed in Kubernetes where scaling is handled by the platform).

### JVM Configuration

The following JVM flags are set via `JAVA_OPTS`:

| Flag | Purpose |
|---|---|
| `-Xmx512m` | Maximum heap size |
| `-Xms256m` | Initial heap size |
| `-XX:+UseContainerSupport` | Enable container-aware JVM |
| `-XX:MaxRAMPercentage=75.0` | Use 75% of container RAM for heap |
| `-XX:+UnlockExperimentalVMOptions` | Enable experimental JVM options |
| `-Dfile.encoding=UTF-8` | Set file encoding |
| `-Duser.timezone=UTC` | Set JVM timezone |

### Maven Build Profiles

| Profile | Server | Database | Use Case |
|---|---|---|---|
| `payara` (default) | Payara | H2 (file) | Local development |
| `glassfish` | GlassFish | H2 (file) | GlassFish testing |
| `cloud` | Payara | PostgreSQL | Production/Cloud |
| `openliberty` | OpenLiberty | HSQLDB | OpenLiberty testing |

For production deployments, build with the `cloud` profile and provide PostgreSQL connection details.

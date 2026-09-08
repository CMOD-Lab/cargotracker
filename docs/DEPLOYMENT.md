# Eclipse Cargo Tracker - GCP GKE Deployment Guide

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to **Google Kubernetes Engine (GKE)**. The application is a Jakarta EE 10 web application running on **Payara Micro**, packaged as a WAR file.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF/PrimeFaces, JMS, Batch)
- **Runtime**: Payara Micro 6.2025.3
- **Java Version**: 11
- **Build Tool**: Maven 3.9.x
- **Package Type**: WAR
- **Application Port**: 8080
- **Context Root**: `/cargo-tracker`
- **Health Endpoints**: `/cargo-tracker/rest/health/live`, `/cargo-tracker/rest/health/ready`

---

## Prerequisites

### Local Development Tools
- **Docker** 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose** 2.x ([Install Docker Compose](https://docs.docker.com/compose/install/))
- **Java 11** (Amazon Corretto or Eclipse Temurin)
- **Maven 3.9+**

### GCP / GKE Tools
- **Google Cloud SDK (gcloud)** ([Install gcloud](https://cloud.google.com/sdk/docs/install))
- **kubectl** ([Install kubectl](https://kubernetes.io/docs/tasks/tools/))
- **GCP Project** with billing enabled
- **GKE Cluster** (Standard or Autopilot)

### Required GCP APIs
Enable the following APIs in your GCP project:
```bash
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

---

## Project Structure

```
cargotracker/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build configuration
├── post-boot-commands.asadmin    # Payara post-boot commands
├── src/
│   └── main/
│       ├── java/                 # Application source code
│       ├── webapp/               # JSF/web resources
│       └── resources/            # Configuration files
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
    └── DEPLOYMENT.md             # This file
```

---

## Local Development Setup

### 1. Build the Application Locally (Optional)
```bash
cd cargotracker
mvn clean package -DskipTests -P payara
```

### 2. Build Docker Image Locally
```bash
docker build -t cargo-tracker:latest .
```

### 3. Run with Docker Compose
```bash
docker-compose up -d
```

Access the application at: **http://localhost:8080/cargo-tracker**

### 4. View Logs
```bash
docker-compose logs -f cargo-tracker
```

### 5. Stop the Application
```bash
docker-compose down
```

---

## Building and Pushing the Docker Image

### Linux / macOS
```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

### Windows
```cmd
scripts\build-push.bat
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select a registry:
   - **Option 1**: Google Artifact Registry
   - **Option 2**: Docker Hub
3. Provide registry credentials

### Manual Build & Push (Google Artifact Registry)
```bash
# Authenticate
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build
docker build -t us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest .

# Push
docker push us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest
```

---

## GCP GKE Deployment

### Step 1: Set Up GCP Project
```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Authenticate
gcloud auth login
```

### Step 2: Create Artifact Registry Repository (if not exists)
```bash
gcloud artifacts repositories create cargo-tracker-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Cargo Tracker Docker images"
```

### Step 3: Create GKE Cluster (if not exists)
```bash
# Standard cluster
gcloud container clusters create cargo-tracker-cluster \
  --zone us-central1-a \
  --num-nodes 2 \
  --machine-type e2-standard-2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 5

# OR Autopilot cluster
gcloud container clusters create-auto cargo-tracker-cluster \
  --region us-central1
```

### Step 4: Configure kubectl
```bash
gcloud container clusters get-credentials cargo-tracker-cluster \
  --zone us-central1-a \
  --project YOUR_PROJECT_ID
```

### Step 5: Deploy Using Script

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
- Docker image URI (full path with tag)
- Optional environment variables (DB_JDBC_URL, DB_USER, DB_PASSWORD, GRAPH_TRAVERSAL_URL)

### Step 6: Manual Deployment (Alternative)

If you prefer to deploy manually:

```bash
# 1. Update the image URI in deployment.yaml
sed -i 's|{{IMAGE_URI}}|us-central1-docker.pkg.dev/MY_PROJECT/MY_REPO/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:/opt/cargo-tracker-data/cargo-tracker-database|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}||g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}||g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml

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
- **Replicas**: 2 (for high availability)
- **Image**: Pulled from your configured registry
- **Resources**: 250m CPU / 512Mi memory (requests), 500m CPU / 1Gi memory (limits)
- **Liveness Probe**: `GET /cargo-tracker/rest/health/live` (starts after 90s, every 30s)
- **Readiness Probe**: `GET /cargo-tracker/rest/health/ready` (starts after 60s, every 15s)
- **Security**: Runs as non-root user (UID 1000)
- **JVM Options**: `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`

### service.yaml
- **Type**: ClusterIP (internal cluster access)
- **Port**: 80 → 8080 (container port)

### ingress.yaml
- **Class**: GCE (Google Cloud Load Balancer)
- **Host**: `cargo-tracker.example.com` (update to your domain)
- **Path**: `/` → `cargo-tracker-service:80`

---

## Configuration Management

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m ...` |
| `DB_JDBC_URL` | Database JDBC URL | H2 file-based |
| `DB_USER` | Database username | (empty) |
| `DB_PASSWORD` | Database password | (empty) |
| `GRAPH_TRAVERSAL_URL` | Graph traversal service URL | localhost |

### Using Kubernetes Secrets for Sensitive Data
```bash
# Create a secret for database credentials
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

---

## GKE Scaling and Management

### Horizontal Pod Autoscaling
```bash
kubectl autoscale deployment cargo-tracker \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n cargo-tracker
```

### Rolling Update (New Image)
```bash
kubectl set image deployment/cargo-tracker \
  cargo-tracker=NEW_IMAGE_URI \
  -n cargo-tracker

kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

### Rollback
```bash
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
```

### Scale Manually
```bash
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker
```

---

## Troubleshooting

### Pod Not Starting
```bash
# Check pod status
kubectl get pods -n cargo-tracker

# Describe pod for events
kubectl describe pod <POD_NAME> -n cargo-tracker

# View pod logs
kubectl logs <POD_NAME> -n cargo-tracker

# View previous container logs (if crashed)
kubectl logs <POD_NAME> -n cargo-tracker --previous
```

### Application Not Accessible
```bash
# Check service
kubectl get svc -n cargo-tracker

# Check ingress
kubectl get ingress -n cargo-tracker
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker

# Port-forward for local testing
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
# Then access: http://localhost:8080/cargo-tracker
```

### Health Check Failures
```bash
# Test health endpoints directly (via port-forward)
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker &
curl http://localhost:8080/cargo-tracker/rest/health
curl http://localhost:8080/cargo-tracker/rest/health/live
curl http://localhost:8080/cargo-tracker/rest/health/ready
```

### JVM Memory Issues
Increase memory limits in `kubernetes/deployment.yaml`:
```yaml
resources:
  requests:
    memory: "1Gi"
  limits:
    memory: "2Gi"
env:
  - name: JAVA_OPTS
    value: "-Xmx1g -Xms512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
```

### Payara Micro Startup Issues
The application may take 60-90 seconds to start due to JVM warm-up and Jakarta EE deployment. The liveness probe has a 90-second initial delay to accommodate this.

---

## Security Considerations

1. **Non-root User**: The container runs as UID 1000 (payara user)
2. **Secrets Management**: Use Kubernetes Secrets or GCP Secret Manager for sensitive data
3. **Network Policies**: Consider adding Kubernetes NetworkPolicy to restrict pod-to-pod communication
4. **Image Scanning**: Enable Artifact Registry vulnerability scanning
5. **RBAC**: Apply least-privilege RBAC for service accounts
6. **TLS**: Configure GKE Managed Certificates for HTTPS:
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

## Java / Jakarta EE Specific Notes

- **Payara Micro**: The application uses Payara Micro as an embedded Jakarta EE runtime. No separate application server installation is needed.
- **H2 Database**: By default, the application uses an embedded H2 file-based database. For production, configure a PostgreSQL database using the `cloud` Maven profile.
- **JMS Messaging**: The application uses JMS queues for internal messaging (cargo handling events). These are configured within Payara Micro.
- **JVM Tuning**: The `-XX:+UseContainerSupport` flag ensures the JVM respects container memory limits. `-XX:MaxRAMPercentage=75.0` limits heap to 75% of container memory.
- **Startup Time**: Payara Micro with Jakarta EE features typically takes 30-90 seconds to start. Adjust probe `initialDelaySeconds` if needed.
- **Context Root**: The application is deployed at `/cargo-tracker`. All URLs should include this prefix.

---

## Useful Commands Reference

```bash
# View all resources in namespace
kubectl get all -n cargo-tracker

# Watch pod status
kubectl get pods -n cargo-tracker -w

# Execute shell in running pod
kubectl exec -it <POD_NAME> -n cargo-tracker -- /bin/bash

# View deployment history
kubectl rollout history deployment/cargo-tracker -n cargo-tracker

# Delete all resources (cleanup)
kubectl delete namespace cargo-tracker
```

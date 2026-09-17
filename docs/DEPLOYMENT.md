# Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to **AWS EKS (Elastic Kubernetes Service)**. Cargo Tracker is a Jakarta EE 10 web application built on **Payara Micro 6.2025.3**, packaged as a WAR file, and deployed as a containerized workload on Kubernetes.

**Technology Stack:**
- Java 11 (runtime: `mcr.microsoft.com/openjdk/jdk:11-ubuntu`)
- Jakarta EE 10 (WAR packaging)
- Payara Micro 6.2025.3 (embedded application server)
- Maven 3.9.4 (build tool)
- PostgreSQL (production database via AWS RDS)
- Redis (session/state externalization via AWS ElastiCache)
- JMS queues (embedded in Payara Micro)

---

## Prerequisites

### Local Development
- Docker Desktop 24.x or later
- Java 11 JDK
- Maven 3.9.x
- Git

### AWS EKS Deployment
- AWS CLI v2 (`aws --version`)
- `kubectl` v1.28+ (`kubectl version --client`)
- `eksctl` v0.180+ (optional, for cluster creation)
- AWS IAM permissions:
  - `eks:DescribeCluster`, `eks:UpdateKubeconfig`
  - `ecr:GetAuthorizationToken`, `ecr:CreateRepository`, `ecr:PutImage`
  - `ec2:DescribeVpcs`, `ec2:DescribeSubnets`
  - `elasticloadbalancing:*` (for ALB Ingress Controller)

---

## Project Structure

```
fullapp/
├── Dockerfile                    # Multi-stage build (CSS minify → HTML minify → Maven build → Runtime)
├── docker-compose.yml            # Local development with Docker
├── .dockerignore                 # Excludes build artifacts and wrapper files
├── pom.xml                       # Maven build descriptor (Java 11, WAR packaging)
├── post-boot-commands.asadmin    # Payara post-boot commands (deploy WAR, add JDBC driver)
├── src/
│   └── main/
│       ├── java/                 # Jakarta EE application source
│       └── webapp/               # JSF/XHTML views, WEB-INF config
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace: cargo-tracker
│   ├── deployment.yaml           # Deployment with 2 replicas, health probes
│   ├── service.yaml              # ClusterIP service on port 80 → 8080
│   └── ingress.yaml              # AWS ALB Ingress with session affinity
├── scripts/
│   ├── build-push.sh             # Linux/macOS: build & push to ECR or Docker Hub
│   ├── build-push.bat            # Windows: build & push to ECR or Docker Hub
│   ├── deploy-image.sh           # Linux/macOS: deploy to AWS EKS
│   └── deploy-image.bat          # Windows: deploy to AWS EKS
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development Setup

### 1. Build the Application Locally (without Docker)

```bash
# Build WAR with H2 database (default Payara profile)
mvn clean package -DskipTests

# Build WAR with PostgreSQL (cloud profile)
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="postgres"
```

### 2. Run with Docker Compose

Create a `.env` file in the project root:

```env
POSTGRESQL_JDBC_URL=jdbc:postgresql://your-rds-host:5432/cargotracker
POSTGRESQL_USERNAME=postgres
POSTGRESQL_PASSWORD=your-password
REDIS_HOST=your-elasticache-endpoint
REDIS_PORT=6379
REDIS_PASSWORD=
```

Start the application:

```bash
docker-compose up --build
```

Access the application at: **http://localhost:8080**

Health check: **http://localhost:8080/rest/health**

Stop the application:

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

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type (1=AWS ECR, 2=Docker Hub)
3. Provide registry credentials and details

### Windows

```cmd
scripts\build-push.bat
```

### Manual Build (ECR Example)

```bash
# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# Create repository (if not exists)
aws ecr create-repository --repository-name cargo-tracker --region us-east-1

# Build and push
docker build -f Dockerfile -t 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest .
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest
```

---

## AWS EKS Prerequisites

### 1. Install AWS Load Balancer Controller

The ingress uses the AWS ALB Ingress Controller. Install it on your EKS cluster:

```bash
# Add the EKS chart repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your-cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name your-cluster-name
kubectl cluster-info
```

### 3. Verify Node Groups

```bash
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

The script will prompt for:
- AWS Region and EKS Cluster Name
- Full Docker image URI (with tag)
- PostgreSQL connection details (JDBC URL, username, password)
- Redis/ElastiCache connection details (host, port, password)

#### Windows

```cmd
scripts\deploy-image.bat
```

### Manual Deployment

#### Step 1: Update deployment.yaml with your image

```bash
sed -i 's|{{IMAGE_URI}}|123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{POSTGRESQL_JDBC_URL}}|jdbc:postgresql://your-rds:5432/cargotracker|g' kubernetes/deployment.yaml
sed -i 's|{{POSTGRESQL_USERNAME}}|postgres|g' kubernetes/deployment.yaml
sed -i 's|{{POSTGRESQL_PASSWORD}}|your-password|g' kubernetes/deployment.yaml
sed -i 's|{{REDIS_HOST}}|your-elasticache.cache.amazonaws.com|g' kubernetes/deployment.yaml
sed -i 's|{{REDIS_PORT}}|6379|g' kubernetes/deployment.yaml
sed -i 's|{{REDIS_PASSWORD}}||g' kubernetes/deployment.yaml
```

#### Step 2: Apply manifests in order

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
```

#### Step 3: Wait for rollout

```bash
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
```

#### Step 4: Verify

```bash
kubectl get pods,svc,ingress -n cargo-tracker
```

---

## Kubernetes Manifest Descriptions

### namespace.yaml
Creates the `cargo-tracker` Kubernetes namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: Pulled from your container registry (placeholder: `{{IMAGE_URI}}`)
- **Port**: 8080 (Payara Micro HTTP)
- **Resources**: requests: 250m CPU / 512Mi RAM; limits: 500m CPU / 1Gi RAM
- **Liveness Probe**: `GET /rest/health` — starts after 120s, checks every 30s
- **Readiness Probe**: `GET /rest/health` — starts after 90s, checks every 15s
- **Environment Variables**: PostgreSQL JDBC URL/credentials, Redis host/port/password
- **Security**: Runs as non-root user (UID 1000)

### service.yaml
- **Type**: ClusterIP (internal cluster access)
- **Port mapping**: 80 → 8080

### ingress.yaml
- **Controller**: AWS ALB (Application Load Balancer)
- **Scheme**: internet-facing
- **Health check path**: `/rest/health`
- **Session affinity**: Enabled (172800s / 48h) — required for Jakarta Faces stateful views
- **SSL redirect**: HTTP → HTTPS (port 443)

---

## Configuration Management

### Environment Variables Reference

| Variable | Description | Example |
|---|---|---|
| `POSTGRESQL_JDBC_URL` | PostgreSQL JDBC connection URL | `jdbc:postgresql://rds-host:5432/cargotracker` |
| `POSTGRESQL_USERNAME` | Database username | `postgres` |
| `POSTGRESQL_PASSWORD` | Database password | `secret` |
| `REDIS_HOST` | ElastiCache primary endpoint | `my-cache.abc123.ng.0001.use1.cache.amazonaws.com` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_PASSWORD` | Redis AUTH password (optional) | `` |
| `JAVA_TOOL_OPTIONS` | JVM flags | `-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0` |
| `TZ` | Timezone | `UTC` |

### Using Kubernetes Secrets (Recommended for Production)

```bash
kubectl create secret generic cargo-tracker-secrets \
  --from-literal=POSTGRESQL_PASSWORD=your-db-password \
  --from-literal=REDIS_PASSWORD=your-redis-password \
  -n cargo-tracker
```

Then reference in deployment.yaml:
```yaml
- name: POSTGRESQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: cargo-tracker-secrets
      key: POSTGRESQL_PASSWORD
```

---

## Scaling and Management

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
  cargo-tracker=123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:v2.0 \
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

### Scale Replicas

```bash
kubectl scale deployment cargo-tracker --replicas=4 -n cargo-tracker
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

**Issue: Pod stuck in `Pending`**
- Check node resources: `kubectl describe nodes`
- Check resource requests vs available capacity

**Issue: Pod in `CrashLoopBackOff`**
- Check logs: `kubectl logs <pod-name> -n cargo-tracker`
- Common causes: incorrect DB/Redis credentials, Payara startup failure

**Issue: Liveness probe failing**
- Payara Micro takes 60-120s to start; check `initialDelaySeconds` in deployment.yaml
- Verify `/rest/health` returns HTTP 200 (requires Redis connectivity)
- Check Redis connection: `REDIS_HOST` and `REDIS_PORT` environment variables

**Issue: Ingress not getting an address**
- Verify AWS Load Balancer Controller is installed: `kubectl get pods -n kube-system | grep aws-load-balancer`
- Check IAM permissions for the controller service account
- Verify subnets are tagged: `kubernetes.io/role/elb=1`

**Issue: Database connection failure**
- Verify RDS security group allows inbound from EKS node security group on port 5432
- Check `POSTGRESQL_JDBC_URL` format: `jdbc:postgresql://host:5432/dbname`

**Issue: Redis connection failure**
- Verify ElastiCache security group allows inbound from EKS node security group on port 6379
- Check `REDIS_HOST` points to the primary endpoint (not reader endpoint)

### Health Check

```bash
# Port-forward to test locally
kubectl port-forward deployment/cargo-tracker 8080:8080 -n cargo-tracker

# Test health endpoint
curl http://localhost:8080/rest/health
```

Expected response:
```json
{"status":"UP","timestamp":"2024-01-01T00:00:00Z","checks":{"application":"UP","redis":"UP"}}
```

---

## Security Considerations

1. **Non-root container**: The application runs as UID 1000 (payara user)
2. **Secrets management**: Use Kubernetes Secrets or AWS Secrets Manager for credentials
3. **Network policies**: Consider adding Kubernetes NetworkPolicy to restrict pod-to-pod traffic
4. **Image scanning**: Enable ECR image scanning for vulnerability detection
5. **RBAC**: Apply least-privilege IAM roles to EKS node groups
6. **TLS**: Configure ACM certificate ARN in ingress annotations for HTTPS:
   ```yaml
   alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789:certificate/xxx
   ```
7. **Pod Security**: Consider adding `securityContext.readOnlyRootFilesystem: true` after testing

---

## Java / Payara-Specific Notes

- **JVM Memory**: Container-aware JVM flags are set: `-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0`
- **Startup Time**: Payara Micro typically takes 60-120 seconds to fully start; health probe `initialDelaySeconds` is set accordingly
- **WAR Context Root**: The application is deployed at `/` (root context) via `post-boot-commands.asadmin`
- **Session Affinity**: Jakarta Faces (JSF) requires sticky sessions; ALB session affinity is configured in ingress.yaml
- **JMS**: JMS queues are embedded in Payara Micro (no external broker required)
- **Database Schema**: JPA auto-creates the schema on first startup (`jakarta.persistence.schema-generation.database.action=create`)
- **Logging**: Payara uses JUL (java.util.logging); configure log levels via Payara admin or system properties

# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment process for the **Eclipse Cargo Tracker** application — a Jakarta EE 10 web application built with Maven, running on Payara Server, and deployed to **AWS EKS (Elastic Kubernetes Service)**.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF/PrimeFaces, JMS, Batch)
- **Build Tool**: Maven 3.9.x
- **Java Version**: 11
- **Package Type**: WAR
- **Application Server**: Payara Server 6.x
- **Default Port**: 8080
- **Context Root**: `/cargo-tracker`

---

## Prerequisites

### Local Development
- Java 11 (JDK)
- Maven 3.9+
- Docker Desktop (latest)
- Git

### AWS EKS Deployment
- AWS CLI v2 (`aws --version`)
- kubectl (`kubectl version`)
- eksctl (optional, for cluster creation)
- AWS IAM permissions:
  - `ecr:*` (ECR access)
  - `eks:*` (EKS access)
  - `ec2:*` (networking)
  - `elasticloadbalancing:*` (ALB Ingress)
  - `iam:CreateServiceLinkedRole`

---

## Project Structure

```
cargotracker/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build configuration
├── post-boot-commands.asadmin    # Payara post-boot commands
├── src/
│   ├── main/
│   │   ├── java/                 # Application source code
│   │   ├── webapp/               # JSF/XHTML web resources
│   │   ├── resources/            # JPA persistence config
│   │   └── liberty/config/       # OpenLiberty config (alternative)
│   └── test/                     # Test sources
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # AWS ALB ingress
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push
│   ├── build-push.bat            # Windows build & push
│   ├── deploy-image.sh           # Linux/macOS EKS deploy
│   └── deploy-image.bat          # Windows EKS deploy
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development Setup

### 1. Build the Application (Maven)

```bash
# Build WAR with Payara profile (default)
mvn clean package -DskipTests -Ppayara

# Build WAR with GlassFish profile
mvn clean package -DskipTests -Pglassfish

# Build WAR with cloud profile (PostgreSQL)
mvn clean package -DskipTests -Pcloud \
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

Access the application at: **http://localhost:8080/cargo-tracker**

### 3. Environment Variables (docker-compose.yml)

| Variable | Default | Description |
|---|---|---|
| `TZ` | `UTC` | Timezone |
| `JAVA_OPTS` | `-Xmx512m -Xms256m ...` | JVM options |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path` | Graph traversal service URL |
| `DB_JDBC_URL` | `jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database` | JDBC URL |
| `DB_USER` | _(empty)_ | Database username |
| `DB_PASSWORD` | _(empty)_ | Database password |

---

## Docker Build

### Build Image Manually

```bash
# Build the Docker image
docker build -t cargo-tracker:latest .

# Run the container
docker run -d \
  -p 8080:8080 \
  -e TZ=UTC \
  -e JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport" \
  --name cargo-tracker \
  cargo-tracker:latest
```

### Multi-Stage Build Details

The Dockerfile uses a two-stage build:

1. **Builder Stage** (`maven:3.9.4-eclipse-temurin-11`):
   - Copies `pom.xml` first for dependency caching
   - Downloads all Maven dependencies
   - Builds the WAR with `mvn clean package -DskipTests -Ppayara`

2. **Runtime Stage** (`eclipse-temurin:11-jdk`):
   - Installs Payara Server 6.x
   - Copies the built WAR to Payara autodeploy directory
   - Runs as non-root `payara` user
   - Exposes port 8080 (HTTP) and 4848 (Admin)

---

## Build and Push to Registry

### Linux/macOS

```bash
# Make script executable
chmod +x scripts/build-push.sh

# Run from project root
./scripts/build-push.sh
```

The script will prompt for:
1. Image tag (default: `latest`)
2. Registry type: AWS ECR or Docker Hub
3. Registry credentials

### Windows

```cmd
scripts\build-push.bat
```

### Manual Push to AWS ECR

```bash
# Set variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="123456789012"
ECR_REPO="cargo-tracker"
IMAGE_TAG="latest"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Create repository (if not exists)
aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION

# Tag and push
docker tag cargo-tracker:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}

docker push \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}
```

---

## AWS EKS Deployment

### Step 1: AWS EKS Prerequisites

#### Install Required Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# eksctl (optional)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

#### Configure AWS CLI

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region, Output format
```

### Step 2: Create EKS Cluster (if needed)

```bash
# Create cluster with eksctl
eksctl create cluster \
  --name cargo-tracker-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

### Step 3: Install AWS Load Balancer Controller

The ingress uses AWS ALB. Install the AWS Load Balancer Controller:

```bash
# Create IAM policy
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=cargo-tracker-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cargo-tracker-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 4: Deploy to EKS

#### Using Deploy Script (Recommended)

```bash
# Linux/macOS
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh

# Windows
scripts\deploy-image.bat
```

The script will prompt for:
- AWS Region
- EKS Cluster Name
- Docker Image URI
- Application environment variables (GRAPH_TRAVERSAL_URL, DB_JDBC_URL, etc.)

#### Manual Deployment

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name cargo-tracker-cluster

# Update image in deployment.yaml
sed -i 's|{{IMAGE_URI}}|123456789012.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}||g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}||g' kubernetes/deployment.yaml

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

### Step 5: Access the Application

```bash
# Get ingress hostname
kubectl get ingress cargo-tracker-ingress -n cargo-tracker

# Access URL
# http://<ALB-HOSTNAME>/cargo-tracker
```

---

## Kubernetes Manifest Details

### namespace.yaml
Creates the `cargo-tracker` namespace to isolate all application resources.

### deployment.yaml
- **Replicas**: 2 (high availability)
- **Image**: Pulled from ECR/Docker Hub (set via `{{IMAGE_URI}}` placeholder)
- **Resources**: 
  - Requests: 250m CPU, 512Mi memory
  - Limits: 500m CPU, 1Gi memory
- **Probes**: TCP socket probes on port 8080 (Payara doesn't expose a standard health endpoint by default)
  - Liveness: Initial delay 90s (JVM + Payara startup time)
  - Readiness: Initial delay 60s

### service.yaml
- **Type**: ClusterIP (internal access only)
- **Port**: 80 → 8080 (container port)

### ingress.yaml
- **Class**: AWS ALB (Application Load Balancer)
- **Scheme**: internet-facing
- **Host**: `cargo-tracker.example.com` (update to your domain)

---

## EKS Scaling and Management

### Horizontal Pod Autoscaler (HPA)

```bash
# Create HPA
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
  cargo-tracker=<NEW_IMAGE_URI> \
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
# Check pod status
kubectl get pods -n cargo-tracker

# Describe pod for events
kubectl describe pod <pod-name> -n cargo-tracker

# View pod logs
kubectl logs <pod-name> -n cargo-tracker
kubectl logs -f deployment/cargo-tracker -n cargo-tracker

# Execute into pod
kubectl exec -it <pod-name> -n cargo-tracker -- /bin/bash
```

### Common Issues

#### Pod stuck in `Pending`
```bash
# Check node resources
kubectl describe nodes
kubectl get events -n cargo-tracker --sort-by='.lastTimestamp'
```

#### Pod in `CrashLoopBackOff`
```bash
# Check logs for startup errors
kubectl logs <pod-name> -n cargo-tracker --previous

# Common causes:
# - Payara startup failure (check JAVA_OPTS memory settings)
# - Database connection failure
# - Missing environment variables
```

#### Ingress not getting hostname
```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify ingress annotations
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker
```

#### Application not accessible
```bash
# Check service endpoints
kubectl get endpoints -n cargo-tracker

# Port-forward for local testing
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker
# Then access: http://localhost:8080/cargo-tracker
```

---

## Configuration Management

### JVM Tuning

The `JAVA_OPTS` environment variable controls JVM settings:

```yaml
env:
  - name: JAVA_OPTS
    value: "-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"
```

For production with larger memory limits:
```
-Xmx1g -Xms512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
```

### Database Configuration

For production, use PostgreSQL with the `cloud` Maven profile:

```bash
# Build with PostgreSQL support
mvn clean package -DskipTests -Pcloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://your-rds-host:5432/cargotracker" \
  -DpostgreSqlUsername="dbuser" \
  -DpostgreSqlPassword="dbpassword"
```

Update Kubernetes deployment environment variables:
```yaml
- name: DB_JDBC_URL
  value: "jdbc:postgresql://your-rds-host:5432/cargotracker"
- name: DB_USER
  value: "dbuser"
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: cargo-tracker-db-secret
      key: password
```

### Kubernetes Secrets for Sensitive Data

```bash
# Create secret for database credentials
kubectl create secret generic cargo-tracker-db-secret \
  --from-literal=password='your-db-password' \
  -n cargo-tracker
```

---

## Security Considerations

1. **Non-root container**: The application runs as the `payara` user (non-root)
2. **Secrets management**: Use Kubernetes Secrets or AWS Secrets Manager for sensitive data
3. **Network policies**: Consider adding NetworkPolicy resources to restrict pod-to-pod communication
4. **Image scanning**: Enable ECR image scanning for vulnerability detection
5. **RBAC**: Apply least-privilege IAM roles for EKS node groups
6. **TLS**: Configure HTTPS on the ALB ingress using ACM certificates:
   ```yaml
   annotations:
     alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789:certificate/xxx
     alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
   ```

---

## Technology-Specific Notes

### Jakarta EE 10 on Payara 6
- Payara Server 6.x is the Jakarta EE 10 certified runtime
- The application uses CDI 4.0, JPA 3.1, JAX-RS 3.1, JSF 4.0, JMS 3.1
- H2 database is embedded for development; PostgreSQL recommended for production
- JMS queues are configured internally within Payara (no external broker needed for default profile)

### Payara Startup Time
- Payara Server takes 60-90 seconds to fully start in a container
- The liveness probe has `initialDelaySeconds: 90` to account for this
- The readiness probe has `initialDelaySeconds: 60`

### Context Root
- The application is deployed at `/cargo-tracker` context root
- Access via: `http://<host>/cargo-tracker`
- REST API: `http://<host>/cargo-tracker/rest/`
- Graph Traversal: `http://<host>/cargo-tracker/rest/graph-traversal/shortest-path`

### Payara Admin Console
- Admin console available at port 4848
- Default credentials: admin/admin
- **Do not expose port 4848 publicly in production**

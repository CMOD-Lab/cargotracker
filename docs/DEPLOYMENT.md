# Eclipse Cargo Tracker - Deployment Guide

## Overview

This guide covers the complete deployment process for the **Eclipse Cargo Tracker** application — a Jakarta EE 10 web application built with Payara Micro, demonstrating Domain-Driven Design (DDD) patterns. The application is containerized using Docker and deployed to **AWS EKS (Elastic Kubernetes Service)**.

- **Application**: Eclipse Cargo Tracker
- **Version**: 3.1-SNAPSHOT
- **Technology**: Jakarta EE 10, Payara Micro 6.x
- **Java Version**: 11
- **Build Tool**: Maven
- **Package Type**: WAR
- **Application Port**: 8080
- **Target Platform**: AWS EKS

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Local Development with Docker Compose](#local-development-with-docker-compose)
4. [Building and Pushing the Docker Image](#building-and-pushing-the-docker-image)
5. [AWS EKS Prerequisites](#aws-eks-prerequisites)
6. [EKS Cluster Setup](#eks-cluster-setup)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Configuration Management](#configuration-management)
9. [Scaling and Management](#scaling-and-management)
10. [Troubleshooting](#troubleshooting)
11. [Security Considerations](#security-considerations)
12. [Technology-Specific Notes](#technology-specific-notes)

---

## Prerequisites

### Local Development Tools
- **Docker** 20.10+ and **Docker Compose** v2+
- **Java 11** (JDK)
- **Maven 3.9+**
- **Git**

### AWS Deployment Tools
- **AWS CLI** v2+ (configured with appropriate IAM permissions)
- **kubectl** v1.28+
- **eksctl** v0.170+ (for cluster creation)
- **Helm** v3+ (optional, for advanced deployments)

### AWS IAM Permissions Required
```
eks:DescribeCluster
eks:UpdateKubeconfig
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:GetDownloadUrlForLayer
ecr:BatchGetImage
ecr:CreateRepository
ecr:DescribeRepositories
ecr:PutImage
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
```

---

## Project Structure

```
cargotracker/
├── Dockerfile                    # Multi-stage Docker build
├── docker-compose.yml            # Local development compose file
├── .dockerignore                 # Docker build exclusions
├── pom.xml                       # Maven build configuration
├── post-boot-commands.asadmin    # Payara Micro post-boot commands
├── src/
│   ├── main/
│   │   ├── java/                 # Application source code
│   │   ├── resources/            # Application resources
│   │   └── webapp/               # Web application files (JSF/XHTML)
│   └── test/                     # Test sources
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── deployment.yaml           # Application deployment
│   ├── service.yaml              # ClusterIP service
│   └── ingress.yaml              # AWS ALB ingress
├── scripts/
│   ├── build-push.sh             # Linux/macOS build & push script
│   ├── build-push.bat            # Windows build & push script
│   ├── deploy-image.sh           # Linux/macOS EKS deploy script
│   └── deploy-image.bat          # Windows EKS deploy script
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development with Docker Compose

### Step 1: Build the Docker Image Locally

```bash
docker build -t cargo-tracker:latest .
```

### Step 2: Start the Application

```bash
docker-compose up -d
```

### Step 3: Access the Application

Open your browser and navigate to:
- **Application**: http://localhost:8080
- **Cargo Tracking**: http://localhost:8080/public/track.xhtml
- **Admin Booking**: http://localhost:8080/booking/booking.xhtml

### Step 4: View Logs

```bash
docker-compose logs -f cargo-tracker
```

### Step 5: Stop the Application

```bash
docker-compose down
```

### Environment Variables (docker-compose)

| Variable | Default | Description |
|---|---|---|
| `TZ` | `UTC` | Timezone setting |
| `JAVA_OPTS` | `-Xmx512m -Xms256m ...` | JVM options |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/...` | Internal routing service URL |
| `DB_JDBC_URL` | `jdbc:h2:file:...` | H2 database JDBC URL |
| `DB_USER` | _(empty)_ | Database username |
| `DB_PASSWORD` | _(empty)_ | Database password |

---

## Building and Pushing the Docker Image

### Linux/macOS

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
2. Select registry type: **AWS ECR** or **Docker Hub**
3. Provide registry credentials

### Manual Build and Push (AWS ECR)

```bash
# Set variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="123456789012"
IMAGE_TAG="latest"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE="${REGISTRY}/cargo-tracker:${IMAGE_TAG}"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $REGISTRY

# Create repository if needed
aws ecr create-repository --repository-name cargo-tracker --region $AWS_REGION 2>/dev/null || true

# Build and push
docker build -t $IMAGE .
docker push $IMAGE
```

---

## AWS EKS Prerequisites

### 1. Install AWS CLI

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configure
aws configure
```

### 2. Install kubectl

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

### 3. Install eksctl (optional, for cluster creation)

```bash
# macOS
brew tap weaveworks/tap && brew install weaveworks/tap/eksctl

# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

---

## EKS Cluster Setup

### Option A: Create a New EKS Cluster

```bash
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

### Option B: Use an Existing Cluster

```bash
aws eks update-kubeconfig --region us-east-1 --name your-cluster-name
kubectl cluster-info
```

### Install AWS Load Balancer Controller (Required for Ingress)

```bash
# Add IAM policy for ALB controller
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cargo-tracker-cluster \
  --set serviceAccount.create=true
```

---

## Kubernetes Deployment

### Automated Deployment (Recommended)

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
- AWS Region
- EKS Cluster Name
- Docker Image URI
- Application environment variables (optional)

### Manual Deployment

#### Step 1: Update the deployment manifest

```bash
# Replace the image placeholder
sed -i 's|{{IMAGE_URI}}|123456789012.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest|g' kubernetes/deployment.yaml
sed -i 's|{{GRAPH_TRAVERSAL_URL}}|http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path|g' kubernetes/deployment.yaml
sed -i 's|{{DB_JDBC_URL}}|jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database|g' kubernetes/deployment.yaml
sed -i 's|{{DB_USER}}||g' kubernetes/deployment.yaml
sed -i 's|{{DB_PASSWORD}}||g' kubernetes/deployment.yaml
```

#### Step 2: Apply manifests in order

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
```

#### Step 3: Verify deployment

```bash
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
kubectl get pods,svc,ingress -n cargo-tracker
```

#### Step 4: Get application URL

```bash
kubectl get ingress cargo-tracker-ingress -n cargo-tracker
```

---

## Configuration Management

### Kubernetes ConfigMap (for non-sensitive config)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cargo-tracker-config
  namespace: cargo-tracker
data:
  GRAPH_TRAVERSAL_URL: "http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"
  TZ: "UTC"
```

### Kubernetes Secret (for sensitive config)

```bash
kubectl create secret generic cargo-tracker-secrets \
  --from-literal=DB_USER=myuser \
  --from-literal=DB_PASSWORD=mypassword \
  -n cargo-tracker
```

Reference in deployment.yaml:
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: cargo-tracker-secrets
        key: DB_PASSWORD
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
  cargo-tracker=123456789012.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:v2.0 \
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
kubectl logs <pod-name> -n cargo-tracker
kubectl logs <pod-name> -n cargo-tracker --previous  # for crashed pods
```

### Common Issues

#### 1. ImagePullBackOff
```bash
# Check ECR permissions and image URI
kubectl describe pod <pod-name> -n cargo-tracker | grep -A5 "Events:"
# Ensure the node IAM role has ECR pull permissions
```

#### 2. CrashLoopBackOff
```bash
# Check application logs
kubectl logs <pod-name> -n cargo-tracker --previous
# Common cause: Payara Micro startup failure, check JAVA_OPTS memory settings
```

#### 3. Ingress Not Getting External IP
```bash
# Check ALB controller is running
kubectl get pods -n kube-system | grep aws-load-balancer
# Check ingress events
kubectl describe ingress cargo-tracker-ingress -n cargo-tracker
```

#### 4. Application Slow to Start
- Payara Micro with Jakarta EE takes 30-60 seconds to start
- Increase `initialDelaySeconds` in liveness/readiness probes if needed
- Check JVM heap settings in `JAVA_OPTS`

#### 5. Out of Memory
```bash
# Increase memory limits in deployment.yaml
resources:
  limits:
    memory: "2Gi"
# Adjust JAVA_OPTS accordingly
env:
  - name: JAVA_OPTS
    value: "-Xmx1g -Xms512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
```

### Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n cargo-tracker

# Execute shell in running pod
kubectl exec -it <pod-name> -n cargo-tracker -- /bin/bash

# Port-forward for local testing
kubectl port-forward svc/cargo-tracker-service 8080:80 -n cargo-tracker

# View resource usage
kubectl top pods -n cargo-tracker
kubectl top nodes
```

---

## Security Considerations

1. **Non-root Container**: The application runs as a non-root user (`payara`) inside the container.
2. **Secrets Management**: Use Kubernetes Secrets or AWS Secrets Manager for sensitive data (DB passwords, API keys).
3. **Network Policies**: Consider adding Kubernetes NetworkPolicies to restrict pod-to-pod communication.
4. **Image Scanning**: Enable ECR image scanning to detect vulnerabilities.
5. **RBAC**: Apply least-privilege RBAC policies for service accounts.
6. **TLS/HTTPS**: Configure HTTPS on the ALB ingress using AWS Certificate Manager (ACM):
   ```yaml
   annotations:
     alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
     alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxx
   ```
7. **Resource Limits**: Always set CPU and memory limits to prevent resource exhaustion.

---

## Technology-Specific Notes

### Jakarta EE / Payara Micro

- **Startup Time**: Payara Micro typically takes 30-60 seconds to fully start. The liveness probe has a 60-second initial delay to accommodate this.
- **H2 Database**: The default profile uses an embedded H2 file database. For production, switch to PostgreSQL using the `cloud` Maven profile.
- **JMS Messaging**: The application uses JMS for internal messaging. Payara Micro provides an embedded JMS broker.
- **CDI**: Context and Dependency Injection is used throughout. Ensure `beans.xml` is present in the WAR.
- **Context Root**: The application is deployed at the root context `/` via Payara Micro's `--contextroot /` flag.

### Java 11 JVM Tuning

```bash
# Recommended JAVA_OPTS for containers
JAVA_OPTS="-Xmx512m -Xms256m \
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=75.0 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+UseG1GC \
  -Djava.security.egd=file:/dev/./urandom \
  -Dfile.encoding=UTF-8 \
  -Duser.timezone=UTC"
```

### Production Database (PostgreSQL)

For production deployments, build with the `cloud` profile:

```bash
mvn clean package -Pcloud \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://your-rds-host:5432/cargotracker" \
  -DpostgreSqlUsername="dbuser" \
  -DpostgreSqlPassword="dbpassword"
```

Update the Kubernetes deployment environment variables accordingly.

### Graph Traversal Service

The application includes an internal graph traversal REST service for routing calculations. In a Kubernetes deployment, the `GRAPH_TRAVERSAL_URL` should point to the internal service:

```
http://cargo-tracker-service.cargo-tracker.svc.cluster.local/cargo-tracker/rest/graph-traversal/shortest-path
```

---

## Quick Reference

```bash
# Build image
docker build -t cargo-tracker:latest .

# Run locally
docker-compose up -d

# Deploy to EKS
./scripts/deploy-image.sh

# Check deployment status
kubectl get pods -n cargo-tracker

# View logs
kubectl logs -l app=cargo-tracker -n cargo-tracker --tail=100

# Scale up
kubectl scale deployment cargo-tracker --replicas=3 -n cargo-tracker

# Rollback
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
```

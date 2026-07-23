# Eclipse Cargo Tracker - AWS ECS Fargate Deployment Guide

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to **AWS ECS Fargate**. The application is a Jakarta EE 10 web application running on **Payara Micro**, packaged as a WAR file.

- **Application**: Eclipse Cargo Tracker v3.1-SNAPSHOT
- **Framework**: Jakarta EE 10 (CDI, JPA, JAX-RS, JSF/PrimeFaces, JMS)
- **Runtime**: Payara Micro 6.2025.3
- **Java Version**: 11
- **Package Type**: WAR
- **Application Port**: 8080
- **Health Endpoint**: `/rest/health`
- **Target Platform**: AWS ECS Fargate

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Local Development with Docker Compose](#local-development-with-docker-compose)
4. [Build and Push Docker Image](#build-and-push-docker-image)
5. [AWS ECS Fargate Prerequisites](#aws-ecs-fargate-prerequisites)
6. [ECS Task Definition Explained](#ecs-task-definition-explained)
7. [ECS Service Configuration](#ecs-service-configuration)
8. [ECS Fargate Deployment Walkthrough](#ecs-fargate-deployment-walkthrough)
9. [ECS-Specific Troubleshooting](#ecs-specific-troubleshooting)
10. [ECS Fargate Scaling and Management](#ecs-fargate-scaling-and-management)
11. [Configuration Management](#configuration-management)
12. [Security Considerations](#security-considerations)
13. [Java/JVM-Specific Notes](#javajvm-specific-notes)

---

## Prerequisites

### Local Development Tools
- **Docker** 20.10+ and **Docker Compose** v2+
- **Java 11** (Eclipse Temurin recommended)
- **Maven 3.9+**
- **AWS CLI v2** configured with appropriate permissions

### AWS Requirements
- AWS account with ECS, ECR, IAM, CloudWatch, and VPC permissions
- VPC with at least 2 subnets (preferably in different AZs)
- Security group allowing inbound TCP on port 8080
- IAM roles: `ecsTaskExecutionRole` and `ecsTaskRole`

---

## Project Structure

```
cargotrackerv1/
├── Dockerfile                    # Multi-stage build (Maven builder + eclipse-temurin:11-jdk runtime)
├── docker-compose.yml            # Local development (application only)
├── .dockerignore                 # Excludes target/, mvnw, .mvn/, test files
├── pom.xml                       # Maven build descriptor (Java 11, WAR packaging)
├── post-boot-commands.asadmin    # Payara Micro post-boot configuration
├── src/                          # Application source code
├── ecs/
│   ├── task-definition.json      # ECS Fargate task definition
│   └── service-definition.json   # ECS Fargate service definition
├── scripts/
│   ├── build-push.sh             # Linux/macOS: build and push to ECR or Docker Hub
│   ├── build-push.bat            # Windows: build and push to ECR or Docker Hub
│   ├── deploy-image.sh           # Linux/macOS: deploy to AWS ECS Fargate
│   └── deploy-image.bat          # Windows: deploy to AWS ECS Fargate
└── docs/
    └── DEPLOYMENT.md             # This file
```

---

## Local Development with Docker Compose

### Start the Application

```bash
# Build and start the application container
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f cargo-tracker

# Stop the application
docker-compose down
```

### Access the Application

- **Application UI**: http://localhost:8080/
- **Health Check**: http://localhost:8080/rest/health
- **REST API**: http://localhost:8080/rest/

### Environment Variable Overrides

Edit `docker-compose.yml` or pass environment variables:

```bash
# Override database URL (for external PostgreSQL)
DB_DRIVER_CLASS=org.postgresql.ds.PGPoolingDataSource \
DB_JDBC_URL=jdbc:postgresql://host:5432/cargotracker \
DB_USER=postgres \
DB_PASSWORD=secret \
docker-compose up
```

---

## Build and Push Docker Image

### Linux/macOS

```bash
# Make script executable
chmod +x scripts/build-push.sh

# Run from project root
./scripts/build-push.sh
```

The script will prompt you to:
1. Select registry type (AWS ECR or Docker Hub)
2. Enter registry credentials and details
3. Enter image tag (defaults to `latest`)

### Windows

```cmd
scripts\build-push.bat
```

### Manual Build

```bash
# Build image
docker build -t cargo-tracker:latest .

# Tag for ECR
docker tag cargo-tracker:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest
```

---

## AWS ECS Fargate Prerequisites

### 1. AWS CLI Configuration

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region, Output format
```

### 2. Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name cargo-tracker \
  --region us-east-1
```

### 3. Create IAM Roles

#### ECS Task Execution Role (required for Fargate)

```bash
# Create the role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach the managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

#### ECS Task Role (for application permissions)

```bash
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'
```

### 4. Create CloudWatch Log Group

```bash
aws logs create-log-group \
  --log-group-name /ecs/cargo-tracker \
  --region us-east-1
```

### 5. VPC and Security Group Setup

```bash
# Create security group (if needed)
aws ec2 create-security-group \
  --group-name cargo-tracker-sg \
  --description "Security group for cargo-tracker ECS tasks" \
  --vpc-id vpc-xxxxxxxx

# Allow inbound HTTP on port 8080
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

# Allow inbound HTTP on port 80 (for ALB)
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

---

## ECS Task Definition Explained

The task definition (`ecs/task-definition.json`) configures how the container runs on Fargate:

```json
{
  "family": "cargo-tracker-task",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "512",
  "memory": "1024",
  ...
}
```

### Key Configuration Points

| Field | Value | Reason |
|-------|-------|--------|
| `requiresCompatibilities` | `["FARGATE"]` | Enables serverless container execution |
| `networkMode` | `awsvpc` | Required for Fargate; each task gets its own ENI |
| `cpu` | `"512"` | 0.5 vCPU - suitable for Jakarta EE app |
| `memory` | `"1024"` | 1 GB RAM - accommodates JVM + Payara Micro |
| `executionRoleArn` | ecsTaskExecutionRole | Allows ECS to pull ECR images and write CloudWatch logs |

### Valid Fargate CPU/Memory Combinations

| CPU | Valid Memory Options |
|-----|---------------------|
| 256 | 512, 1024, 2048 MB |
| 512 | 1024, 2048, 3072, 4096 MB |
| 1024 | 2048–8192 MB |
| 2048 | 4096–16384 MB |
| 4096 | 8192–30720 MB |

### Container Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_OPTS` | `-Xmx512m -Xms256m ...` | JVM heap and container support flags |
| `TZ` | `UTC` | Timezone for the JVM |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/rest/...` | Internal routing service URL |
| `DB_DRIVER_CLASS` | H2 JDBC driver | Database driver class |
| `DB_JDBC_URL` | H2 file URL | JDBC connection URL |
| `DB_USER` | (empty) | Database username |
| `DB_PASSWORD` | (empty) | Database password |

### CloudWatch Logging

All container stdout/stderr is sent to CloudWatch Logs:
- **Log Group**: `/ecs/cargo-tracker`
- **Stream Prefix**: `ecs`
- **Log Driver**: `awslogs`

---

## ECS Service Configuration

The service definition (`ecs/service-definition.json`) manages how tasks are scheduled:

```json
{
  "serviceName": "cargo-tracker-service",
  "launchType": "FARGATE",
  "desiredCount": 2,
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["subnet-xxx", "subnet-yyy"],
      "securityGroups": ["sg-xxx"],
      "assignPublicIp": "ENABLED"
    }
  }
}
```

### Key Service Settings

| Setting | Value | Description |
|---------|-------|-------------|
| `desiredCount` | 2 | Run 2 tasks for high availability |
| `maximumPercent` | 200 | Allow up to 4 tasks during rolling deploy |
| `minimumHealthyPercent` | 50 | Keep at least 1 task running during deploy |
| `assignPublicIp` | ENABLED | Required for tasks in public subnets to pull ECR images |

---

## ECS Fargate Deployment Walkthrough

### Step 1: Build and Push Image

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
# Select: 1 (AWS ECR)
# Enter: region, repo name, tag
```

### Step 2: Deploy to ECS

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

The script will prompt for:
- AWS Region
- ECS Cluster name
- ECR Image URI
- VPC ID
- Subnet IDs (comma-separated)
- Security Group ID
- Whether to create an Application Load Balancer

### Step 3: Verify Deployment

```bash
# Check service status
aws ecs describe-services \
  --cluster cargo-tracker-cluster \
  --services cargo-tracker-service \
  --region us-east-1

# List running tasks
aws ecs list-tasks \
  --cluster cargo-tracker-cluster \
  --service-name cargo-tracker-service \
  --region us-east-1

# View application logs
aws logs tail /ecs/cargo-tracker --follow --region us-east-1
```

### Step 4: Access the Application

If using ALB:
```
http://<alb-dns-name>/
http://<alb-dns-name>/rest/health
```

If using direct task IP (development only):
```
http://<task-public-ip>:8080/
http://<task-public-ip>:8080/rest/health
```

---

## ECS-Specific Troubleshooting

### Task Fails to Start

```bash
# Describe the stopped task to see the stop reason
aws ecs describe-tasks \
  --cluster cargo-tracker-cluster \
  --tasks <task-arn> \
  --region us-east-1 \
  --query "tasks[0].{Status:lastStatus,StopCode:stopCode,StopReason:stoppedReason}"
```

**Common causes:**
- `CannotPullContainerError`: ECR permissions issue or image not found
  - Verify `ecsTaskExecutionRole` has `AmazonECSTaskExecutionRolePolicy`
  - Verify image URI is correct
- `OutOfMemoryError`: Increase task memory (e.g., from 1024 to 2048 MB)
- `ResourceInitializationError`: Fargate agent issue; retry the deployment

### Container Exits Immediately

```bash
# Check CloudWatch logs
aws logs get-log-events \
  --log-group-name /ecs/cargo-tracker \
  --log-stream-name ecs/cargo-tracker/<task-id> \
  --region us-east-1
```

**Common causes:**
- Payara Micro startup failure (check logs for `SEVERE` messages)
- Database connection failure (verify DB_JDBC_URL and credentials)
- Port conflict (ensure port 8080 is not blocked)

### Network Connectivity Issues

- Verify security group allows inbound TCP on port 8080
- Verify subnets have route to internet gateway (for public subnets)
- For private subnets: ensure NAT gateway exists for ECR image pulls
- Verify `assignPublicIp: ENABLED` for public subnet deployments

### CPU/Memory Errors

```
InvalidParameterException: Invalid CPU or memory value specified
```

Use only valid Fargate combinations:
- CPU 512 → Memory must be 1024, 2048, 3072, or 4096

### Health Check Failures

The application health endpoint is `/rest/health`. Verify:
```bash
# Test health endpoint directly
curl http://<task-ip>:8080/rest/health
# Expected: {"status":"UP","application":"cargo-tracker","timestamp":"..."}
```

If using ALB, check target group health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1
```

---

## ECS Fargate Scaling and Management

### Manual Scaling

```bash
# Scale up to 4 tasks
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --desired-count 4 \
  --region us-east-1
```

### Auto Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/cargo-tracker-cluster/cargo-tracker-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create CPU-based scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/cargo-tracker-cluster/cargo-tracker-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cargo-tracker-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleInCooldown": 300,
    "ScaleOutCooldown": 60
  }'
```

### Blue/Green Deployment

For zero-downtime deployments, use AWS CodeDeploy with ECS:

```bash
# Update service with new image (rolling update)
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --task-definition cargo-tracker-task:<new-revision> \
  --region us-east-1
```

### Force New Deployment

```bash
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --force-new-deployment \
  --region us-east-1
```

---

## Configuration Management

### Environment Variables in ECS

Update environment variables in `ecs/task-definition.json` and re-register:

```bash
# Edit task-definition.json, then register new revision
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-definition.json \
  --region us-east-1

# Update service to use new task definition
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --task-definition cargo-tracker-task \
  --region us-east-1
```

### AWS Secrets Manager (Recommended for Passwords)

```bash
# Store database password
aws secretsmanager create-secret \
  --name cargo-tracker/db-password \
  --secret-string "your-db-password"
```

Then reference in task definition:
```json
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:cargo-tracker/db-password"
  }
]
```

---

## Security Considerations

1. **Non-root container**: The Dockerfile creates a `payara` user and runs the application as non-root.

2. **IAM least privilege**: The `ecsTaskRole` should only have permissions the application needs. Avoid using `AdministratorAccess`.

3. **Network isolation**: Use private subnets with NAT gateway for production. Only expose the ALB publicly.

4. **Secrets management**: Never store passwords in environment variables in plain text. Use AWS Secrets Manager or SSM Parameter Store.

5. **Image scanning**: Enable ECR image scanning:
   ```bash
   aws ecr put-image-scanning-configuration \
     --repository-name cargo-tracker \
     --image-scanning-configuration scanOnPush=true
   ```

6. **Security group rules**: Restrict inbound access to only necessary ports and CIDR ranges.

7. **TLS/HTTPS**: Configure HTTPS on the ALB with an ACM certificate for production.

---

## Java/JVM-Specific Notes

### JVM Memory Configuration

The container is configured with:
```
-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
```

- `-XX:+UseContainerSupport`: Enables JVM to respect container memory limits (Java 11+)
- `-XX:MaxRAMPercentage=75.0`: JVM uses up to 75% of container memory
- With 1024 MB task memory, JVM heap can grow to ~768 MB

### Payara Micro Startup Time

Payara Micro typically takes 30-60 seconds to start. The ECS service is configured with:
- `healthCheckGracePeriodSeconds: 300` (when ALB is used)
- This prevents premature task replacement during startup

### Garbage Collection

For containerized Java 11 applications, the default G1GC is appropriate. For lower latency:
```
-XX:+UseZGC  # Java 15+ only
```

### JVM Monitoring

To enable JMX monitoring (development only):
```
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9010
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
```

### Thread Dump for Troubleshooting

```bash
# Get task ID
TASK_ARN=$(aws ecs list-tasks --cluster cargo-tracker-cluster --service-name cargo-tracker-service --query "taskArns[0]" --output text)

# Execute command in running container (requires ECS Exec enabled)
aws ecs execute-command \
  --cluster cargo-tracker-cluster \
  --task $TASK_ARN \
  --container cargo-tracker \
  --interactive \
  --command "kill -3 1"
```

---

## Quick Reference

```bash
# Build and push
./scripts/build-push.sh

# Deploy
./scripts/deploy-image.sh

# View logs
aws logs tail /ecs/cargo-tracker --follow --region us-east-1

# Scale
aws ecs update-service --cluster cargo-tracker-cluster --service cargo-tracker-service --desired-count 3 --region us-east-1

# Force redeploy
aws ecs update-service --cluster cargo-tracker-cluster --service cargo-tracker-service --force-new-deployment --region us-east-1

# Health check
curl http://<task-ip>:8080/rest/health
```

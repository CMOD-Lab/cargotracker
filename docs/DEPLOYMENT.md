# CareTracker Application - AWS ECS Fargate Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Analysis](#project-analysis)
4. [Local Development with Docker Compose](#local-development-with-docker-compose)
5. [Build and Push Docker Image](#build-and-push-docker-image)
6. [AWS ECS Fargate Prerequisites](#aws-ecs-fargate-prerequisites)
7. [ECS Task Definition Explained](#ecs-task-definition-explained)
8. [ECS Service Configuration](#ecs-service-configuration)
9. [ECS Fargate Deployment Walkthrough](#ecs-fargate-deployment-walkthrough)
10. [ECS-Specific Troubleshooting](#ecs-specific-troubleshooting)
11. [ECS Fargate Scaling and Management](#ecs-fargate-scaling-and-management)
12. [Configuration Management](#configuration-management)
13. [Security Considerations](#security-considerations)
14. [Technology-Specific Notes](#technology-specific-notes)

---

## Overview

**Application**: CareTracker (Eclipse Cargo Tracker)  
**Framework**: Jakarta EE 10 on Payara Server Full 6.x  
**Java Version**: 11  
**Build Tool**: Maven  
**Package Type**: WAR  
**Application Port**: 8080  
**Runtime Image**: `payara/server-full:6.2023.12`  
**Target Platform**: AWS ECS Fargate  

The CareTracker application is a Jakarta EE 10 web application built on the Eclipse Cargo Tracker reference implementation. It uses Payara Server Full as the application server, Jakarta Faces (JSF) with PrimeFaces for the UI, JPA/EclipseLink for persistence, and JMS for messaging.

---

## Prerequisites

### Local Development
- Docker Desktop 24.x or later
- Docker Compose v2.x or later
- Java 11 JDK (for local builds outside Docker)
- Maven 3.9.x (for local builds outside Docker)
- AWS CLI v2 (for cloud deployment)

### AWS Deployment
- AWS CLI v2 configured with appropriate credentials
- AWS Account with permissions for:
  - ECS (create clusters, task definitions, services)
  - ECR (create repositories, push images)
  - IAM (create/assign roles)
  - CloudWatch Logs (create log groups)
  - VPC/EC2 (security groups, subnets)
  - Elastic Load Balancing (optional, for ALB)

---

## Project Analysis

| Property | Value |
|----------|-------|
| Framework | Jakarta EE 10 / Payara Server Full |
| Java Version | 11 |
| Build Tool | Maven |
| Package Type | WAR |
| Application Port | 8080 |
| Admin Port | 4848 |
| Base Image | payara/server-full:6.2023.12 |
| Database (dev) | H2 (embedded, file-based) |
| Database (prod) | PostgreSQL |
| Messaging | JMS (built-in Payara) |
| UI Framework | Jakarta Faces + PrimeFaces 14 |

---

## Local Development with Docker Compose

### Quick Start

```bash
# 1. Build and start the application
docker compose up --build

# 2. Access the application
open http://localhost:8080

# 3. Access Payara Admin Console (optional)
open http://localhost:4848
# Default credentials: admin / admin

# 4. Stop the application
docker compose down

# 5. Stop and remove volumes
docker compose down -v
```

### Environment Variables (docker-compose.yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_OPTS` | `-Xmx512m -Xms256m ...` | JVM tuning flags |
| `TZ` | `UTC` | Timezone |
| `GRAPH_TRAVERSAL_URL` | `http://localhost:8080/...` | Internal routing service URL |

### Building the WAR Locally (without Docker)

```bash
# Default profile (Payara + H2)
mvn clean package -DskipTests

# Cloud profile (Payara + PostgreSQL)
mvn clean package -Pcloud -DskipTests \
  -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
  -DpostgreSqlUsername="postgres" \
  -DpostgreSqlPassword="yourpassword"
```

---

## Build and Push Docker Image

### Linux/macOS

```bash
# Make the script executable
chmod +x scripts/build-push.sh

# Run from project root
./scripts/build-push.sh
```

The script will prompt you to:
1. Enter an image tag (default: `latest`)
2. Select registry type (AWS ECR or Docker Hub)
3. Provide registry credentials and details

### Windows

```cmd
REM Run from project root
scripts\build-push.bat
```

### Manual Build and Push (AWS ECR)

```bash
# Set variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="cargo-tracker"
IMAGE_TAG="latest"
REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $REGISTRY_URL

# Create ECR repository (if not exists)
aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION 2>/dev/null || true

# Build image
docker build -f Dockerfile -t $FULL_IMAGE .

# Push image
docker push $FULL_IMAGE

echo "Image URI: $FULL_IMAGE"
```

---

## AWS ECS Fargate Prerequisites

### 1. IAM Roles

#### ECS Task Execution Role
This role allows ECS to pull images from ECR and write logs to CloudWatch.

```bash
# Create the execution role
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

# If using Secrets Manager for DB credentials, also attach:
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

#### ECS Task Role (Optional)
This role grants the application container permissions to call AWS services.

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

### 2. VPC and Networking

```bash
# List available VPCs
aws ec2 describe-vpcs --query "Vpcs[*].{VpcId:VpcId,CIDR:CidrBlock,Default:IsDefault}" --output table

# List subnets (use at least 2 in different AZs for HA)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxx" \
  --query "Subnets[*].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}" \
  --output table
```

### 3. Security Group

```bash
# Create security group for the application
SG_ID=$(aws ec2 create-security-group \
  --group-name cargo-tracker-sg \
  --description "Security group for CareTracker ECS tasks" \
  --vpc-id vpc-xxxxxxxx \
  --query "GroupId" \
  --output text)

# Allow inbound HTTP on port 8080
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

# Allow inbound HTTP on port 80 (if using ALB)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

echo "Security Group ID: $SG_ID"
```

### 4. CloudWatch Log Group

```bash
aws logs create-log-group \
  --log-group-name /ecs/cargo-tracker \
  --region us-east-1

# Set retention policy (optional)
aws logs put-retention-policy \
  --log-group-name /ecs/cargo-tracker \
  --retention-in-days 30
```

---

## ECS Task Definition Explained

The task definition (`ecs/task-definition.json`) configures how the container runs on Fargate:

### Key Fields

| Field | Value | Description |
|-------|-------|-------------|
| `family` | `cargo-tracker-task` | Task definition family name |
| `requiresCompatibilities` | `["FARGATE"]` | Must be FARGATE for serverless containers |
| `networkMode` | `awsvpc` | Required for Fargate; each task gets its own ENI |
| `cpu` | `"512"` | 0.5 vCPU (valid Fargate unit) |
| `memory` | `"1024"` | 1 GB RAM |
| `executionRoleArn` | `ecsTaskExecutionRole` | Allows ECS to pull images and write logs |

### Valid Fargate CPU/Memory Combinations

| CPU | Valid Memory Options |
|-----|---------------------|
| 256 (.25 vCPU) | 512, 1024, 2048 MB |
| **512 (.5 vCPU)** | **1024, 2048, 3072, 4096 MB** ← Default |
| 1024 (1 vCPU) | 2048–8192 MB |
| 2048 (2 vCPU) | 4096–16384 MB |
| 4096 (4 vCPU) | 8192–30720 MB |

> **Note**: Payara Server Full requires at least 512 MB. For production workloads, consider `cpu: "1024"` and `memory: "2048"`.

### Container Definition

The container definition includes:
- **Port mapping**: Container port 8080 (TCP)
- **Environment variables**: JVM options, timezone, graph traversal URL
- **Secrets**: Database credentials from AWS Secrets Manager
- **Log configuration**: CloudWatch Logs via `awslogs` driver

### Secrets Manager Integration

The task definition references secrets for database credentials. Create them before deploying:

```bash
# Create database URL secret
aws secretsmanager create-secret \
  --name cargo-tracker/db-url \
  --secret-string "jdbc:postgresql://your-db-host:5432/cargotracker" \
  --region us-east-1

# Create database username secret
aws secretsmanager create-secret \
  --name cargo-tracker/db-username \
  --secret-string "postgres" \
  --region us-east-1

# Create database password secret
aws secretsmanager create-secret \
  --name cargo-tracker/db-password \
  --secret-string "yourpassword" \
  --region us-east-1
```

> **Note**: If you are using the embedded H2 database (development only), remove the `secrets` section from the task definition.

---

## ECS Service Configuration

The service definition (`ecs/service-definition.json`) controls how tasks are managed:

| Field | Value | Description |
|-------|-------|-------------|
| `serviceName` | `cargo-tracker-service` | ECS service name |
| `launchType` | `FARGATE` | Serverless container execution |
| `desiredCount` | `2` | Number of running task instances |
| `networkMode` | `awsvpc` | Each task gets its own IP |
| `assignPublicIp` | `ENABLED` | Required if tasks need internet access |
| `maximumPercent` | `200` | Allow 2x tasks during rolling deploy |
| `minimumHealthyPercent` | `50` | Keep at least 50% healthy during deploy |

---

## ECS Fargate Deployment Walkthrough

### Step 1: Push Image to ECR

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
# Select option 1 (AWS ECR)
# Note the full image URI output
```

### Step 2: Run Deployment Script

```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```

Provide the following when prompted:
- **AWS Region**: e.g., `us-east-1`
- **ECS Cluster name**: e.g., `cargo-tracker-cluster`
- **ECR Image URI**: from Step 1
- **VPC ID**: your VPC ID
- **Subnet IDs**: comma-separated (e.g., `subnet-aaa,subnet-bbb`)
- **Security Group ID**: the SG created in prerequisites
- **Load Balancer**: `y` for production, `n` for testing

### Step 3: Verify Deployment

```bash
# Check service status
aws ecs describe-services \
  --cluster cargo-tracker-cluster \
  --services cargo-tracker-service \
  --region us-east-1 \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}" \
  --output table

# View application logs
aws logs tail /ecs/cargo-tracker --follow --region us-east-1

# List running tasks
aws ecs list-tasks \
  --cluster cargo-tracker-cluster \
  --service-name cargo-tracker-service \
  --region us-east-1
```

### Step 4: Access the Application

- **Direct task IP**: Find the task's public IP from the ECS console or:
  ```bash
  TASK_ARN=$(aws ecs list-tasks --cluster cargo-tracker-cluster \
    --service-name cargo-tracker-service --query "taskArns[0]" --output text)
  aws ecs describe-tasks --cluster cargo-tracker-cluster --tasks $TASK_ARN \
    --query "tasks[0].attachments[0].details" --output table
  ```
- **Via ALB**: Use the DNS name printed by the deploy script
- **URL**: `http://<ip-or-alb-dns>:8080/` (or port 80 via ALB)

---

## ECS-Specific Troubleshooting

### Task Fails to Start

```bash
# Check stopped task reason
TASK_ARN=$(aws ecs list-tasks --cluster cargo-tracker-cluster \
  --desired-status STOPPED --query "taskArns[0]" --output text)
aws ecs describe-tasks --cluster cargo-tracker-cluster --tasks $TASK_ARN \
  --query "tasks[0].{StopCode:stopCode,StoppedReason:stoppedReason,Containers:containers[*].{Name:name,Reason:reason,ExitCode:exitCode}}" \
  --output json
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `CannotPullContainerError` | ECR auth failure | Verify `executionRoleArn` has ECR pull permissions |
| `OutOfMemoryError` | Insufficient memory | Increase `memory` in task definition (try 2048) |
| Task stops immediately | Payara startup failure | Check CloudWatch logs for Java errors |
| `ResourceInitializationError` | Network issue | Verify subnets have internet access (NAT or public) |
| Port not accessible | Security group | Ensure SG allows inbound TCP on port 8080 |
| DB connection failure | Wrong credentials | Verify Secrets Manager values and task role permissions |
| Slow startup | JVM warm-up | Increase `startPeriod` in health check; Payara takes 60-90s |

### View Container Logs

```bash
# Stream logs in real-time
aws logs tail /ecs/cargo-tracker --follow --region us-east-1

# Get last 100 log events
aws logs get-log-events \
  --log-group-name /ecs/cargo-tracker \
  --log-stream-name "ecs/cargo-tracker/<task-id>" \
  --limit 100 \
  --region us-east-1
```

### CPU/Memory Errors

If you see `RESOURCE:MEMORY` or `RESOURCE:CPU` errors:
```bash
# Update task definition with more resources
# Edit ecs/task-definition.json:
# "cpu": "1024"    (1 vCPU)
# "memory": "2048" (2 GB)
# Then re-register and update service
```

---

## ECS Fargate Scaling and Management

### Manual Scaling

```bash
# Scale up to 4 instances
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --desired-count 4 \
  --region us-east-1

# Scale down to 1 instance
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --desired-count 1 \
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

### Blue/Green Deployment with CodeDeploy

For zero-downtime deployments, configure CodeDeploy with ECS:

```bash
# Update service for CodeDeploy blue/green
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --deployment-controller '{"type": "CODE_DEPLOY"}' \
  --region us-east-1
```

### Rolling Update (Default)

The default deployment strategy uses rolling updates:
- `maximumPercent: 200` → Allows double the tasks during deployment
- `minimumHealthyPercent: 50` → Keeps at least half the tasks running

---

## Configuration Management

### Environment Variables

Configure application behavior via environment variables in the task definition:

| Variable | Description | Example |
|----------|-------------|---------|
| `JAVA_OPTS` | JVM tuning flags | `-Xmx512m -Xms256m -XX:+UseContainerSupport` |
| `TZ` | Timezone | `UTC` |
| `GRAPH_TRAVERSAL_URL` | Internal routing service URL | `http://localhost:8080/cargo-tracker/rest/...` |

### Database Configuration

For production, use PostgreSQL with Secrets Manager:

```bash
# Update task definition to use cloud profile
# The WAR must be built with -Pcloud profile for PostgreSQL support
# Build command: mvn clean package -Pcloud -DskipTests \
#   -DpostgreSqlJdbcUrl="..." -DpostgreSqlUsername="..." -DpostgreSqlPassword="..."
```

### Updating Configuration

```bash
# Register new task definition revision with updated env vars
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-definition.json \
  --region us-east-1

# Update service to use new revision
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --task-definition cargo-tracker-task \
  --region us-east-1
```

---

## Security Considerations

### Container Security
- The Payara base image runs as a non-root user by default
- No additional packages are installed in the runtime image
- Secrets are injected via AWS Secrets Manager (not environment variables in plaintext)

### Network Security
- Use private subnets with NAT Gateway for production (remove `assignPublicIp: ENABLED`)
- Restrict security group inbound rules to ALB security group only
- Enable VPC Flow Logs for network monitoring

### IAM Least Privilege
- `ecsTaskExecutionRole`: Only ECR pull + CloudWatch write permissions
- `ecsTaskRole`: Grant only the AWS service permissions the app actually needs
- Rotate database credentials regularly via Secrets Manager rotation

### Image Security
- Regularly update the `payara/server-full` base image for security patches
- Scan images with Amazon ECR image scanning:
  ```bash
  aws ecr start-image-scan \
    --repository-name cargo-tracker \
    --image-id imageTag=latest \
    --region us-east-1
  ```

### Secrets Management
- Never store database passwords in environment variables or task definitions in plaintext
- Use AWS Secrets Manager with automatic rotation
- Audit secret access via CloudTrail

---

## Technology-Specific Notes

### Jakarta EE / Payara Server

- **Startup Time**: Payara Server Full takes 60-90 seconds to start. Configure ALB health check grace period to at least 120 seconds.
- **Admin Console**: Port 4848 is exposed but should NOT be publicly accessible in production. Remove port 4848 from the security group for production deployments.
- **JMS**: The application uses built-in Payara JMS (OpenMQ). No external message broker is required.
- **H2 Database**: The embedded H2 database is suitable for development only. Use PostgreSQL for production.
- **WAR Deployment**: The WAR is deployed via `post-boot-commands.asadmin` which runs after Payara starts.

### JVM Tuning for Containers

```
-Xmx512m              # Maximum heap size (adjust based on task memory)
-Xms256m              # Initial heap size
-XX:+UseContainerSupport    # Enable container-aware JVM (Java 11+)
-XX:MaxRAMPercentage=75.0   # Use 75% of container memory for heap
-XX:+UnlockExperimentalVMOptions  # Required for some experimental flags
```

For a 1024 MB Fargate task:
- Container memory: 1024 MB
- JVM heap (75%): ~768 MB
- Remaining for Payara/Metaspace/threads: ~256 MB

For production, consider increasing to `cpu: "1024"` and `memory: "2048"`.

### Maven Build Notes

- The Dockerfile uses the `cloud` Maven profile (`-Pcloud`) which includes the PostgreSQL JDBC driver
- The system `mvn` command is used (NOT `./mvnw`) to avoid wrapper dependency issues
- Build artifacts: `target/cargo-tracker.war` and `target/postgresql.jar`

### Payara-Specific Docker Notes

- The `post-boot-commands.asadmin` file is copied to `/opt/payara/config/` and executed automatically on startup
- It adds the PostgreSQL JDBC library and deploys the WAR with context root `/`
- The application is accessible at `http://host:8080/` (root context)

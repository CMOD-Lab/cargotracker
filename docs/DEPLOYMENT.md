# Cargo Tracker - AWS ECS Fargate Deployment Guide

## Overview

This guide covers the complete deployment of the **Eclipse Cargo Tracker** application to **AWS ECS Fargate**. Cargo Tracker is a Jakarta EE 10 application built on Payara Server, demonstrating Domain-Driven Design (DDD) patterns.

- **Technology**: Jakarta EE 10, Payara Server 6.x
- **Build Tool**: Maven 3.x
- **Java Version**: 11
- **Package Type**: WAR
- **Application Port**: 8080
- **Context Root**: `/cargo-tracker`

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development with Docker Compose](#local-development-with-docker-compose)
3. [Build and Push Docker Image](#build-and-push-docker-image)
4. [AWS ECS Fargate Prerequisites](#aws-ecs-fargate-prerequisites)
5. [ECS Task Definition Explained](#ecs-task-definition-explained)
6. [ECS Service Configuration](#ecs-service-configuration)
7. [ECS Fargate Deployment Walkthrough](#ecs-fargate-deployment-walkthrough)
8. [ECS-Specific Troubleshooting](#ecs-specific-troubleshooting)
9. [ECS Fargate Scaling and Management](#ecs-fargate-scaling-and-management)
10. [Configuration Management](#configuration-management)
11. [Security Considerations](#security-considerations)
12. [Jakarta EE Specific Notes](#jakarta-ee-specific-notes)

---

## Prerequisites

### Local Development Requirements
- **Docker** 20.10+ and **Docker Compose** 2.x
- **Java 11** (Amazon Corretto 11 or Eclipse Temurin 11)
- **Maven 3.8+**
- **Git**

### AWS Deployment Requirements
- **AWS CLI** v2 configured with appropriate permissions
- **AWS Account** with ECS, ECR, IAM, CloudWatch access
- **VPC** with at least 2 public or private subnets in different AZs
- **Security Group** allowing inbound TCP on port 8080 (and 80 if using ALB)
- **IAM Roles**: `ecsTaskExecutionRole` and optionally `ecsTaskRole`

### Required AWS CLI Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ecr:*",
        "iam:PassRole",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "elbv2:*",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Local Development with Docker Compose

### Quick Start

1. **Build the application WAR** (required before Docker build):
   ```bash
   mvn clean package -DskipTests -Ppayara
   ```

2. **Start the application**:
   ```bash
   docker-compose up --build
   ```

3. **Access the application**:
   - Application: http://localhost:8080/cargo-tracker/
   - Admin Console: http://localhost:4848/

4. **Stop the application**:
   ```bash
   docker-compose down
   ```

### Environment Variables for Local Development

Create a `.env` file in the project root:
```env
DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource
DB_USER=
DB_PASSWORD=
GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
TZ=UTC
```

### Docker Compose Services

The `docker-compose.yml` contains **only the application service**. External services (databases, message queues) are configured via environment variables.

---

## Build and Push Docker Image

### Linux/macOS

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

The script will prompt you to:
1. Select registry type (AWS ECR or Docker Hub)
2. Enter registry credentials and details
3. Specify an image tag (defaults to `latest`)

### Windows

```cmd
scripts\build-push.bat
```

### Manual Build

```bash
# Build the WAR first
mvn clean package -DskipTests -Ppayara

# Build Docker image
docker build -t cargo-tracker:latest .

# Tag for ECR
docker tag cargo-tracker:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest
```

---

## AWS ECS Fargate Prerequisites

### 1. Create IAM Roles

#### ECS Task Execution Role
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

### 2. Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name cargo-tracker \
  --region us-east-1
```

### 3. Create CloudWatch Log Group

```bash
aws logs create-log-group \
  --log-group-name /ecs/cargo-tracker \
  --region us-east-1
```

### 4. Configure Security Group

Ensure your security group allows:
- **Inbound**: TCP port 8080 from ALB security group (or 0.0.0.0/0 for testing)
- **Inbound**: TCP port 80 on ALB security group from 0.0.0.0/0
- **Outbound**: All traffic (for ECR image pulls, CloudWatch logs)

---

## ECS Task Definition Explained

The task definition (`ecs/task-definition.json`) is configured for **AWS Fargate**:

### Key Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `requiresCompatibilities` | `["FARGATE"]` | Fargate launch type |
| `networkMode` | `awsvpc` | Required for Fargate |
| `cpu` | `"512"` | 0.5 vCPU |
| `memory` | `"1024"` | 1 GB RAM |
| `containerPort` | `8080` | Payara HTTP port |

### Valid Fargate CPU/Memory Combinations

| CPU | Valid Memory Options |
|-----|---------------------|
| 256 (.25 vCPU) | 512, 1024, 2048 MB |
| **512 (.5 vCPU)** | **1024, 2048, 3072, 4096 MB** |
| 1024 (1 vCPU) | 2048–8192 MB |
| 2048 (2 vCPU) | 4096–16384 MB |
| 4096 (4 vCPU) | 8192–30720 MB |

### JVM Configuration

The container uses these JVM flags:
```
-Xmx512m -Xms256m
-XX:+UseContainerSupport
-XX:MaxRAMPercentage=75.0
-XX:+UnlockExperimentalVMOptions
-Djava.net.preferIPv4Stack=true
```

> **Note**: For production workloads, consider increasing to `cpu: "1024"` and `memory: "2048"` to accommodate Payara Server's overhead.

### Logging Configuration

Logs are sent to CloudWatch Logs:
- **Log Group**: `/ecs/cargo-tracker`
- **Log Driver**: `awslogs`
- **Stream Prefix**: `ecs`

---

## ECS Service Configuration

The service definition (`ecs/service-definition.json`) configures:

### High Availability
- **Desired Count**: 2 tasks (for HA)
- **Maximum Percent**: 200% (allows rolling updates)
- **Minimum Healthy Percent**: 50% (keeps at least 1 task running)

### Networking (awsvpc mode)
- Each task gets its own ENI (Elastic Network Interface)
- Tasks can be placed in public or private subnets
- Security groups applied at the task level

### Load Balancing
When using an ALB:
- Target type must be `ip` (required for Fargate awsvpc mode)
- Health check path: `/cargo-tracker/`
- Health check grace period: 300 seconds (Payara startup time)

---

## ECS Fargate Deployment Walkthrough

### Step 1: Configure AWS CLI

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region, Output format
```

### Step 2: Build and Push Image

```bash
# Linux/macOS
chmod +x scripts/build-push.sh
./scripts/build-push.sh

# Windows
scripts\build-push.bat
```

### Step 3: Deploy to ECS Fargate

```bash
# Linux/macOS
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh

# Windows
scripts\deploy-image.bat
```

The deployment script will prompt for:
- AWS Region
- ECS Cluster name
- ECR Image URI
- VPC ID
- Subnet IDs (comma-separated)
- Security Group ID
- Whether to create an Application Load Balancer

### Step 4: Verify Deployment

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

# View logs
aws logs tail /ecs/cargo-tracker --follow --region us-east-1
```

### Step 5: Access the Application

- **With ALB**: `http://<alb-dns-name>/cargo-tracker/`
- **Direct task IP**: `http://<task-public-ip>:8080/cargo-tracker/`

---

## ECS-Specific Troubleshooting

### Task Fails to Start

**Symptom**: Tasks stop immediately after starting.

**Diagnosis**:
```bash
# Get stopped task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster cargo-tracker-cluster \
  --desired-status STOPPED \
  --region us-east-1 \
  --query "taskArns[0]" --output text)

# Describe the stopped task
aws ecs describe-tasks \
  --cluster cargo-tracker-cluster \
  --tasks $TASK_ARN \
  --region us-east-1 \
  --query "tasks[0].{StopCode:stopCode,StoppedReason:stoppedReason,Containers:containers[*].{Name:name,Reason:reason,ExitCode:exitCode}}"
```

**Common Causes**:
- `CannotPullContainerError`: ECR permissions issue → Check `ecsTaskExecutionRole`
- `OutOfMemoryError`: Increase task memory → Use `cpu: "1024"`, `memory: "2048"`
- `ResourceInitializationError`: VPC/subnet configuration issue

### Network Connectivity Issues

**Symptom**: Tasks start but application is unreachable.

**Checks**:
1. Security group allows inbound on port 8080
2. Subnets have route to internet (for public subnets: Internet Gateway; for private: NAT Gateway)
3. `assignPublicIp: ENABLED` for public subnets

```bash
# Check task network interface
aws ecs describe-tasks \
  --cluster cargo-tracker-cluster \
  --tasks $TASK_ARN \
  --region us-east-1 \
  --query "tasks[0].attachments"
```

### Payara Server Startup Issues

**Symptom**: Health checks fail, tasks restart repeatedly.

**Cause**: Payara Server takes 60-120 seconds to start. The ALB health check grace period is set to 300 seconds.

**Fix**: Increase `healthCheckGracePeriodSeconds` if needed:
```bash
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --health-check-grace-period-seconds 600 \
  --region us-east-1
```

### CPU/Memory Errors

**Symptom**: `InvalidParameterException: Invalid CPU or memory value specified`

**Fix**: Use valid Fargate combinations only:
```json
{
  "cpu": "512",
  "memory": "1024"
}
```

### CloudWatch Logs Not Appearing

**Checks**:
1. Log group `/ecs/cargo-tracker` exists
2. `ecsTaskExecutionRole` has `logs:CreateLogStream` and `logs:PutLogEvents` permissions
3. Correct region in `awslogs-region`

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
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/cargo-tracker-cluster/cargo-tracker-service \
  --min-capacity 2 \
  --max-capacity 10

# Create CPU-based scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/cargo-tracker-cluster/cargo-tracker-service \
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

### Blue/Green Deployments

For zero-downtime deployments, use AWS CodeDeploy with ECS:

```bash
# Update service with new image (rolling update)
aws ecs update-service \
  --cluster cargo-tracker-cluster \
  --service cargo-tracker-service \
  --task-definition cargo-tracker-task:NEW_REVISION \
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

### Environment Variables

Key environment variables for the application:

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m ...` |
| `DB_JDBC_URL` | Database JDBC URL | H2 file-based |
| `DB_DRIVER_CLASS` | JDBC driver class | H2 datasource |
| `DB_USER` | Database username | (empty) |
| `DB_PASSWORD` | Database password | (empty) |
| `GRAPH_TRAVERSAL_URL` | Pathfinder service URL | localhost |

### Using AWS Secrets Manager

For sensitive values (database passwords):

```bash
# Store secret
aws secretsmanager create-secret \
  --name cargo-tracker/db-password \
  --secret-string "your-db-password"

# Reference in task definition
{
  "secrets": [{
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:cargo-tracker/db-password"
  }]
}
```

### Using AWS Systems Manager Parameter Store

```bash
# Store parameter
aws ssm put-parameter \
  --name "/cargo-tracker/db-jdbc-url" \
  --value "jdbc:postgresql://host:5432/cargotracker" \
  --type "SecureString"
```

---

## Security Considerations

### Container Security
- Application runs as non-root user `payara`
- No unnecessary packages installed in runtime image
- Use specific image tags (not `latest`) in production

### Network Security
- Use private subnets for ECS tasks in production
- Place ALB in public subnets, tasks in private subnets
- Restrict security group rules to minimum required ports
- Enable VPC Flow Logs for network monitoring

### IAM Security
- Follow principle of least privilege for task roles
- Rotate ECR credentials regularly (handled automatically by ECS)
- Use resource-based policies to restrict ECR access

### Secrets Management
- Never hardcode credentials in task definitions
- Use AWS Secrets Manager or SSM Parameter Store
- Enable encryption at rest for sensitive parameters

### Image Security
- Scan ECR images for vulnerabilities:
  ```bash
  aws ecr start-image-scan \
    --repository-name cargo-tracker \
    --image-id imageTag=latest \
    --region us-east-1
  ```
- Use Amazon Inspector for continuous vulnerability scanning
- Keep base images updated (amazoncorretto:11)

---

## Jakarta EE Specific Notes

### Payara Server Configuration

The application uses **Payara Server 6.x** which implements Jakarta EE 10. Key considerations:

1. **Startup Time**: Payara Server typically takes 60-120 seconds to fully start. Configure ALB health check grace period accordingly (300 seconds recommended).

2. **JMS Queues**: The application uses JMS queues for asynchronous messaging. In containerized environments, these are configured via `web.xml` JMS destination definitions.

3. **H2 Database**: The default profile uses H2 embedded database. For production, configure PostgreSQL via the `cloud` Maven profile:
   ```bash
   mvn clean package -Pcloud \
     -DpostgreSqlJdbcUrl="jdbc:postgresql://host:5432/postgres" \
     -DpostgreSqlUsername="user" \
     -DpostgreSqlPassword="password"
   ```

4. **Context Root**: The application deploys to `/cargo-tracker` context root. Access via `http://host:8080/cargo-tracker/`.

5. **Admin Console**: Payara admin console is available on port 4848. Do not expose this port publicly.

### Jakarta EE Health Monitoring

Since this is a Jakarta EE application (not Spring Boot), there is no `/actuator/health` endpoint. Health monitoring options:

- **ALB Health Check**: Configure to check `GET /cargo-tracker/` (returns HTTP 200)
- **Custom Health Endpoint**: Implement a JAX-RS endpoint at `/cargo-tracker/rest/health`
- **TCP Health Check**: Check if port 8080 is accepting connections

### Persistence Configuration

The application uses JPA with EclipseLink. Schema generation is set to `create` by default (suitable for development). For production:
- Change `jakarta.persistence.schema-generation.database.action` to `none` or `validate`
- Use database migration tools (Flyway/Liquibase) for schema management

### REST API Endpoints

The application exposes REST endpoints under `/cargo-tracker/rest/`:
- `GET /cargo-tracker/rest/graph-traversal/shortest-path` - Pathfinder service
- Various booking and tracking endpoints

---

## Quick Reference Commands

```bash
# Build application
mvn clean package -DskipTests -Ppayara

# Build Docker image
docker build -t cargo-tracker:latest .

# Run locally
docker-compose up

# Deploy to ECS
./scripts/deploy-image.sh

# View ECS service status
aws ecs describe-services --cluster cargo-tracker-cluster --services cargo-tracker-service --region us-east-1

# View application logs
aws logs tail /ecs/cargo-tracker --follow --region us-east-1

# Scale service
aws ecs update-service --cluster cargo-tracker-cluster --service cargo-tracker-service --desired-count 3 --region us-east-1

# Force new deployment
aws ecs update-service --cluster cargo-tracker-cluster --service cargo-tracker-service --force-new-deployment --region us-east-1
```

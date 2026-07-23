#!/bin/bash
set -e
set -o pipefail

# =============================================================================
# Deploy to AWS ECS Fargate - Cargo Tracker
# Jakarta EE application on Payara Server
# =============================================================================

PROJECT_NAME="cargo-tracker"
SERVICE_NAME="cargo-tracker-service"
TASK_FAMILY="cargo-tracker-task"
LOG_GROUP="/ecs/cargo-tracker"
TASK_DEF_FILE="ecs/task-definition.json"
SERVICE_DEF_FILE="ecs/service-definition.json"

echo "=============================================="
echo "  Cargo Tracker - AWS ECS Fargate Deployment"
echo "=============================================="
echo ""

# -----------------------------------------------
# Collect deployment parameters
# -----------------------------------------------
read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
read -p "Enter ECS Cluster name [default: cargo-tracker-cluster]: " CLUSTER_INPUT
CLUSTER_NAME="${CLUSTER_INPUT:-cargo-tracker-cluster}"

read -p "Enter ECR Image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): " IMAGE_URI

read -p "Enter VPC ID (e.g., vpc-xxxxxxxx): " VPC_ID
read -p "Enter Subnet IDs (comma-separated, e.g., subnet-aaa,subnet-bbb): " SUBNETS_INPUT
read -p "Enter Security Group ID (e.g., sg-xxxxxxxx): " SECURITY_GROUP

# Parse subnets
SUBNET_1=$(echo "$SUBNETS_INPUT" | cut -d',' -f1 | tr -d ' ')
SUBNET_2=$(echo "$SUBNETS_INPUT" | cut -d',' -f2 | tr -d ' ')
if [ -z "$SUBNET_2" ]; then
  SUBNET_2="$SUBNET_1"
fi

# -----------------------------------------------
# Get AWS Account ID
# -----------------------------------------------
echo ""
echo "Retrieving AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# -----------------------------------------------
# Ensure CloudWatch Log Group exists
# -----------------------------------------------
echo ""
echo "Ensuring CloudWatch log group '$LOG_GROUP' exists..."
aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$AWS_REGION" 2>/dev/null || true
echo "Log group ready: $LOG_GROUP"

# -----------------------------------------------
# Check / Create ECS Cluster
# -----------------------------------------------
echo ""
echo "Checking ECS cluster '$CLUSTER_NAME'..."
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "clusters[0].status" --output text 2>/dev/null || echo "MISSING")

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
  echo "Cluster not found or inactive. Creating cluster '$CLUSTER_NAME'..."
  aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION"
  echo "Cluster created: $CLUSTER_NAME"
else
  echo "Cluster '$CLUSTER_NAME' is ACTIVE."
fi

# -----------------------------------------------
# Load Balancer (optional)
# -----------------------------------------------
echo ""
read -p "Do you need an Application Load Balancer for this service? (y/n): " NEED_LB
USE_LB=false
TARGET_GROUP_ARN=""
ALB_DNS=""

if [ "$NEED_LB" = "y" ] || [ "$NEED_LB" = "Y" ]; then
  USE_LB=true
  ALB_NAME="cargo-tracker-alb"
  TG_NAME="cargo-tracker-tg"

  echo ""
  echo "Creating Application Load Balancer '$ALB_NAME'..."
  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets "$SUBNET_1" "$SUBNET_2" \
    --security-groups "$SECURITY_GROUP" \
    --scheme internet-facing \
    --type application \
    --region "$AWS_REGION" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)
  echo "ALB ARN: $ALB_ARN"

  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$AWS_REGION" \
    --query "LoadBalancers[0].DNSName" \
    --output text)

  echo "Creating Target Group '$TG_NAME'..."
  TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "$TG_NAME" \
    --protocol HTTP \
    --port 8080 \
    --vpc-id "$VPC_ID" \
    --target-type ip \
    --health-check-path "/cargo-tracker/" \
    --health-check-interval-seconds 60 \
    --health-check-timeout-seconds 30 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 5 \
    --region "$AWS_REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)
  echo "Target Group ARN: $TARGET_GROUP_ARN"

  echo "Creating ALB Listener on port 80..."
  aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$TARGET_GROUP_ARN" \
    --region "$AWS_REGION" >/dev/null
  echo "ALB Listener created."
fi

# -----------------------------------------------
# Prepare task definition JSON (replace placeholders)
# -----------------------------------------------
echo ""
echo "Preparing task definition..."
cp "$TASK_DEF_FILE" /tmp/task-definition-deploy.json

sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" /tmp/task-definition-deploy.json
sed -i "s|{{AWS_REGION}}|${AWS_REGION}|g" /tmp/task-definition-deploy.json
sed -i "s|{{ACCOUNT_ID}}|${ACCOUNT_ID}|g" /tmp/task-definition-deploy.json

# -----------------------------------------------
# Register Task Definition
# -----------------------------------------------
echo "Registering ECS task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/task-definition-deploy.json \
  --region "$AWS_REGION" \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)
echo "Task Definition ARN: $TASK_DEF_ARN"

# -----------------------------------------------
# Prepare service definition JSON (replace placeholders)
# -----------------------------------------------
echo ""
echo "Preparing service definition..."
cp "$SERVICE_DEF_FILE" /tmp/service-definition-deploy.json

sed -i "s|{{CLUSTER_NAME}}|${CLUSTER_NAME}|g" /tmp/service-definition-deploy.json
sed -i "s|{{SUBNET_1}}|${SUBNET_1}|g" /tmp/service-definition-deploy.json
sed -i "s|{{SUBNET_2}}|${SUBNET_2}|g" /tmp/service-definition-deploy.json
sed -i "s|{{SECURITY_GROUP}}|${SECURITY_GROUP}|g" /tmp/service-definition-deploy.json

# Handle load balancer in service definition
if [ "$USE_LB" = true ]; then
  # Inject loadBalancers section using Python (available on most systems)
  python3 -c "
import json, sys
with open('/tmp/service-definition-deploy.json') as f:
    svc = json.load(f)
svc['loadBalancers'] = [{
    'targetGroupArn': '${TARGET_GROUP_ARN}',
    'containerName': 'cargo-tracker',
    'containerPort': 8080
}]
svc['healthCheckGracePeriodSeconds'] = 300
with open('/tmp/service-definition-deploy.json', 'w') as f:
    json.dump(svc, f, indent=2)
"
fi

# -----------------------------------------------
# Create or Update ECS Service
# -----------------------------------------------
echo ""
echo "Checking if ECS service '$SERVICE_NAME' exists..."
EXISTING_SERVICE=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query "services[?status!='INACTIVE'].serviceName" \
  --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_SERVICE" ] || [ "$EXISTING_SERVICE" = "None" ]; then
  echo "Service does not exist. Creating ECS service '$SERVICE_NAME'..."
  # Update task definition in service JSON
  python3 -c "
import json
with open('/tmp/service-definition-deploy.json') as f:
    svc = json.load(f)
svc['taskDefinition'] = '${TASK_DEF_ARN}'
with open('/tmp/service-definition-deploy.json', 'w') as f:
    json.dump(svc, f, indent=2)
"
  aws ecs create-service \
    --cli-input-json file:///tmp/service-definition-deploy.json \
    --region "$AWS_REGION"
  echo "ECS service '$SERVICE_NAME' created."
else
  echo "Service '$SERVICE_NAME' exists. Updating service with new task definition..."
  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --task-definition "$TASK_DEF_ARN" \
    --region "$AWS_REGION" >/dev/null
  echo "ECS service updated."
fi

# -----------------------------------------------
# Wait for service stability
# -----------------------------------------------
echo ""
echo "Waiting for ECS service to stabilize (this may take several minutes)..."
aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION"
echo "Service is stable!"

# -----------------------------------------------
# Verify deployment
# -----------------------------------------------
echo ""
echo "=============================================="
echo "  Deployment Verification"
echo "=============================================="
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query "services[0].{ServiceName:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}" \
  --output table

echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo "Cluster       : $CLUSTER_NAME"
echo "Service       : $SERVICE_NAME"
echo "Task Def ARN  : $TASK_DEF_ARN"
echo "CloudWatch Logs: $LOG_GROUP"
if [ "$USE_LB" = true ] && [ -n "$ALB_DNS" ]; then
  echo "Load Balancer : http://$ALB_DNS/cargo-tracker/"
fi
echo ""
echo "Troubleshooting tips:"
echo "  - View logs: aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo "  - List tasks: aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION"
echo "  - Describe tasks: aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks <task-arn> --region $AWS_REGION"
echo ""

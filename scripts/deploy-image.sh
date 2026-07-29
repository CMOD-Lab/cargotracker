#!/bin/bash
# =============================================================================
# deploy-image.sh - Deploy CareTracker to AWS ECS Fargate
# =============================================================================
set -e
set -o pipefail

SERVICE_NAME="cargo-tracker-service"
TASK_FAMILY="cargo-tracker-task"
PROJECT_NAME="cargo-tracker"
LOG_GROUP="/ecs/cargo-tracker"

echo "=============================================="
echo "  CareTracker - AWS ECS Fargate Deployment"
echo "=============================================="
echo ""

# ---- Gather configuration ----
read -rp "Enter AWS Region [us-east-1]: " AWS_REGION
AWS_REGION="${AWS_REGION:-us-east-1}"

read -rp "Enter ECS Cluster name [cargo-tracker-cluster]: " CLUSTER_NAME
CLUSTER_NAME="${CLUSTER_NAME:-cargo-tracker-cluster}"

read -rp "Enter ECR Image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Image URI is required."
  exit 1
fi

read -rp "Enter VPC ID (e.g. vpc-xxxxxxxx): " VPC_ID
if [ -z "$VPC_ID" ]; then
  echo "ERROR: VPC ID is required."
  exit 1
fi

read -rp "Enter Subnet IDs (comma-separated, e.g. subnet-aaa,subnet-bbb): " SUBNETS_INPUT
if [ -z "$SUBNETS_INPUT" ]; then
  echo "ERROR: At least one subnet is required."
  exit 1
fi
SUBNET_1=$(echo "$SUBNETS_INPUT" | cut -d',' -f1 | tr -d ' ')
SUBNET_2=$(echo "$SUBNETS_INPUT" | cut -d',' -f2 | tr -d ' ')
if [ -z "$SUBNET_2" ]; then
  SUBNET_2="$SUBNET_1"
fi

read -rp "Enter Security Group ID (e.g. sg-xxxxxxxx): " SECURITY_GROUP
if [ -z "$SECURITY_GROUP" ]; then
  echo "ERROR: Security Group ID is required."
  exit 1
fi

# ---- Get AWS Account ID ----
echo ""
echo "Fetching AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# ---- Ensure CloudWatch log group exists ----
echo ""
echo "Ensuring CloudWatch log group exists: $LOG_GROUP ..."
aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$AWS_REGION" 2>/dev/null || true
echo "Log group ready."

# ---- Check/create ECS cluster ----
echo ""
echo "Checking ECS cluster: $CLUSTER_NAME ..."
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "clusters[0].status" --output text 2>/dev/null || echo "MISSING")
if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
  echo "Creating ECS cluster: $CLUSTER_NAME ..."
  aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION"
  echo "Cluster created."
else
  echo "Cluster already exists and is ACTIVE."
fi

# ---- Load balancer prompt ----
echo ""
read -rp "Do you need an Application Load Balancer for this service? (y/n) [n]: " NEED_LB
NEED_LB="${NEED_LB:-n}"

TARGET_GROUP_ARN=""
ALB_DNS=""
if [[ "$NEED_LB" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Creating Application Load Balancer..."
  read -rp "Enter a name for the ALB [cargo-tracker-alb]: " ALB_NAME_INPUT
  ALB_NAME="${ALB_NAME_INPUT:-cargo-tracker-alb}"

  # Get all subnets for ALB (needs at least 2)
  ALL_SUBNETS=$(echo "$SUBNETS_INPUT" | tr ',' ' ')

  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets $ALL_SUBNETS \
    --security-groups "$SECURITY_GROUP" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region "$AWS_REGION" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)
  echo "ALB created: $ALB_ARN"

  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$AWS_REGION" \
    --query "LoadBalancers[0].DNSName" \
    --output text)

  echo "Creating Target Group (type: ip for Fargate awsvpc)..."
  TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "cargo-tracker-tg" \
    --protocol HTTP \
    --port 8080 \
    --vpc-id "$VPC_ID" \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --region "$AWS_REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)
  echo "Target Group created: $TARGET_GROUP_ARN"

  echo "Creating ALB Listener on port 80..."
  aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$TARGET_GROUP_ARN" \
    --region "$AWS_REGION" >/dev/null
  echo "ALB Listener created."
fi

# ---- Prepare task definition ----
echo ""
echo "Preparing task definition..."
TASK_DEF_FILE=$(mktemp /tmp/task-def-XXXXXX.json)
cp "$(dirname "$0")/../ecs/task-definition.json" "$TASK_DEF_FILE"

sed -i "s|{{IMAGE_URI}}|$IMAGE_URI|g" "$TASK_DEF_FILE"
sed -i "s|{{AWS_REGION}}|$AWS_REGION|g" "$TASK_DEF_FILE"
sed -i "s|{{ACCOUNT_ID}}|$ACCOUNT_ID|g" "$TASK_DEF_FILE"

# ---- Register task definition ----
echo "Registering ECS task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json "file://$TASK_DEF_FILE" \
  --region "$AWS_REGION" \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)
echo "Task definition registered: $TASK_DEF_ARN"
rm -f "$TASK_DEF_FILE"

# ---- Prepare service definition ----
echo ""
echo "Preparing service definition..."
SERVICE_DEF_FILE=$(mktemp /tmp/service-def-XXXXXX.json)
cp "$(dirname "$0")/../ecs/service-definition.json" "$SERVICE_DEF_FILE"

sed -i "s|{{CLUSTER_NAME}}|$CLUSTER_NAME|g" "$SERVICE_DEF_FILE"
sed -i "s|{{SUBNET_1}}|$SUBNET_1|g" "$SERVICE_DEF_FILE"
sed -i "s|{{SUBNET_2}}|$SUBNET_2|g" "$SERVICE_DEF_FILE"
sed -i "s|{{SECURITY_GROUP}}|$SECURITY_GROUP|g" "$SERVICE_DEF_FILE"

# ---- Add load balancer config if needed ----
if [[ "$NEED_LB" =~ ^[Yy]$ ]] && [ -n "$TARGET_GROUP_ARN" ]; then
  # Use Python to inject loadBalancers into the service definition JSON
  python3 - <<PYEOF
import json, sys
with open("$SERVICE_DEF_FILE", "r") as f:
    svc = json.load(f)
svc["loadBalancers"] = [{
    "targetGroupArn": "$TARGET_GROUP_ARN",
    "containerName": "cargo-tracker",
    "containerPort": 8080
}]
svc["healthCheckGracePeriodSeconds"] = 300
with open("$SERVICE_DEF_FILE", "w") as f:
    json.dump(svc, f, indent=2)
PYEOF
fi

# ---- Check if service exists ----
echo ""
echo "Checking if ECS service exists: $SERVICE_NAME ..."
EXISTING_SERVICE=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query "services[?status!='INACTIVE'].serviceName" \
  --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_SERVICE" ] || [ "$EXISTING_SERVICE" = "None" ]; then
  echo "Creating new ECS service: $SERVICE_NAME ..."
  aws ecs create-service \
    --cli-input-json "file://$SERVICE_DEF_FILE" \
    --region "$AWS_REGION"
  echo "Service created."
else
  echo "Updating existing ECS service: $SERVICE_NAME ..."
  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --task-definition "$TASK_DEF_ARN" \
    --region "$AWS_REGION" >/dev/null
  echo "Service updated."
fi

rm -f "$SERVICE_DEF_FILE"

# ---- Wait for stability ----
echo ""
echo "Waiting for service to stabilize (this may take several minutes)..."
aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION"
echo "Service is stable."

# ---- Verify deployment ----
echo ""
echo "=============================================="
echo "  Deployment Verification"
echo "=============================================="
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}" \
  --output table

echo ""
echo "CloudWatch Log Group: $LOG_GROUP"
echo "  View logs: aws logs tail $LOG_GROUP --follow --region $AWS_REGION"

if [ -n "$ALB_DNS" ]; then
  echo ""
  echo "Application Load Balancer DNS: http://$ALB_DNS"
  echo "  (DNS propagation may take a few minutes)"
fi

echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo ""
echo "Troubleshooting tips:"
echo "  - Check task logs: aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo "  - List tasks: aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION"
echo "  - Describe tasks: aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks <task-arn> --region $AWS_REGION"
echo "  - Ensure security group allows inbound TCP on port 8080"
echo "  - Payara startup can take 60-90 seconds; check logs if tasks are stopping"

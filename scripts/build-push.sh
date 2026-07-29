#!/bin/bash
# =============================================================================
# build-push.sh - Build and Push Docker Image for CareTracker (cargo-tracker)
# =============================================================================
set -e

PROJECT_NAME="cargo-tracker"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=============================================="
echo "  CareTracker Application - Build & Push"
echo "=============================================="
echo ""

# Prompt for image tag
read -rp "Enter image tag [latest]: " IMAGE_TAG_INPUT
IMAGE_TAG=$(echo "${IMAGE_TAG_INPUT:-latest}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi
echo "Using image tag: $IMAGE_TAG"
echo ""

# Registry selection
echo "Select container registry:"
echo "  1. AWS ECR (Elastic Container Registry)"
echo "  2. Docker Hub"
read -rp "Enter choice [1]: " REGISTRY_CHOICE
REGISTRY_CHOICE="${REGISTRY_CHOICE:-1}"

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- AWS ECR ----
  echo ""
  echo "--- AWS ECR Configuration ---"
  read -rp "Enter AWS Region [us-east-1]: " AWS_REGION
  AWS_REGION="${AWS_REGION:-us-east-1}"
  read -rp "Enter AWS Account ID: " AWS_ACCOUNT_ID
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Fetching AWS Account ID..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "Account ID: $AWS_ACCOUNT_ID"
  fi
  read -rp "Enter ECR repository name [$IMAGE_NAME]: " ECR_REPO_INPUT
  ECR_REPO="${ECR_REPO_INPUT:-$IMAGE_NAME}"
  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to AWS ECR..."
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
  if [ $? -ne 0 ]; then
    echo "ERROR: ECR login failed."
    exit 1
  fi

  echo "Checking/creating ECR repository: $ECR_REPO ..."
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
  echo "ECR repository ready."

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  echo ""
  echo "--- Docker Hub Configuration ---"
  read -rp "Enter Docker Hub username: " DOCKER_USERNAME
  read -rsp "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  read -rp "Enter Docker Hub repository [$DOCKER_USERNAME/$IMAGE_NAME]: " DOCKER_REPO_INPUT
  DOCKER_REPO="${DOCKER_REPO_INPUT:-$DOCKER_USERNAME/$IMAGE_NAME}"
  FULL_IMAGE_NAME="${DOCKER_REPO}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Docker Hub..."
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  if [ $? -ne 0 ]; then
    echo "ERROR: Docker Hub login failed."
    exit 1
  fi

else
  echo "ERROR: Invalid registry choice."
  exit 1
fi

echo ""
echo "=============================================="
echo "Building Docker image..."
echo "  Image: $FULL_IMAGE_NAME"
echo "  Context: . (project root)"
echo "=============================================="

docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi
echo "Docker build successful."

echo ""
echo "Pushing image: $FULL_IMAGE_NAME ..."
docker push "$FULL_IMAGE_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "=============================================="
echo "SUCCESS: Image pushed successfully!"
echo "  Full image URI: $FULL_IMAGE_NAME"
echo "  Use this URI in your ECS task definition."
echo "=============================================="

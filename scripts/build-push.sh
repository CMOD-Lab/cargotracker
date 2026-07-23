#!/bin/bash
# =============================================================================
# build-push.sh - Build and push Docker image for cargo-tracker
# Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
# =============================================================================
set -e

PROJECT_NAME="cargo-tracker"
DOCKERFILE_PATH="Dockerfile"
BUILD_CONTEXT="."

echo "=============================================="
echo "  cargo-tracker - Docker Build & Push Script"
echo "=============================================="
echo ""

# Sanitize image name: lowercase, replace non-alphanumeric with hyphens, trim hyphens
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
echo "Image name: ${IMAGE_NAME}"

# Prompt for image tag
read -p "Enter image tag [latest]: " IMAGE_TAG_INPUT
IMAGE_TAG=$(echo "${IMAGE_TAG_INPUT:-latest}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi
echo "Image tag: ${IMAGE_TAG}"
echo ""

# Select registry type
echo "Select container registry:"
echo "  1. AWS ECR (Elastic Container Registry)"
echo "  2. Docker Hub"
read -p "Enter choice [1]: " REGISTRY_CHOICE
REGISTRY_CHOICE="${REGISTRY_CHOICE:-1}"

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- AWS ECR ----
  echo ""
  echo "--- AWS ECR Configuration ---"
  read -p "Enter AWS Region [us-east-1]: " AWS_REGION
  AWS_REGION="${AWS_REGION:-us-east-1}"

  read -p "Enter ECR repository name [${IMAGE_NAME}]: " ECR_REPO_INPUT
  ECR_REPO="${ECR_REPO_INPUT:-${IMAGE_NAME}}"

  # Get AWS Account ID
  echo "Retrieving AWS Account ID..."
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  if [ -z "$ACCOUNT_ID" ]; then
    echo "ERROR: Could not retrieve AWS Account ID. Ensure AWS CLI is configured."
    exit 1
  fi
  echo "AWS Account ID: ${ACCOUNT_ID}"

  REGISTRY_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to AWS ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY_URL}"
  if [ $? -ne 0 ]; then
    echo "ERROR: ECR login failed."
    exit 1
  fi
  echo "ECR login successful."

  # Auto-create ECR repository if it doesn't exist
  echo "Checking if ECR repository '${ECR_REPO}' exists..."
  aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "${ECR_REPO}" --region "${AWS_REGION}"
  echo "ECR repository ready."

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  echo ""
  echo "--- Docker Hub Configuration ---"
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  read -p "Enter Docker Hub namespace/org [${DOCKER_USERNAME}]: " DOCKER_NAMESPACE_INPUT
  DOCKER_NAMESPACE="${DOCKER_NAMESPACE_INPUT:-${DOCKER_USERNAME}}"

  FULL_IMAGE_NAME="${DOCKER_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Docker Hub..."
  echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin
  if [ $? -ne 0 ]; then
    echo "ERROR: Docker Hub login failed."
    exit 1
  fi
  echo "Docker Hub login successful."

else
  echo "ERROR: Invalid registry choice '${REGISTRY_CHOICE}'. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "=============================================="
echo "  Building Docker image..."
echo "  Image: ${FULL_IMAGE_NAME}"
echo "  Dockerfile: ${DOCKERFILE_PATH}"
echo "  Context: ${BUILD_CONTEXT}"
echo "=============================================="

docker build -f "${DOCKERFILE_PATH}" -t "${FULL_IMAGE_NAME}" "${BUILD_CONTEXT}"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi
echo "Docker build successful."

# Also tag as local image name for convenience
docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo "Pushing image to registry..."
docker push "${FULL_IMAGE_NAME}"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "=============================================="
echo "  SUCCESS!"
echo "  Image pushed: ${FULL_IMAGE_NAME}"
echo "=============================================="
echo ""
echo "To deploy to ECS, run: ./scripts/deploy-image.sh"
echo "Use image URI: ${FULL_IMAGE_NAME}"

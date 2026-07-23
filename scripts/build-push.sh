#!/bin/bash
set -e

# =============================================================================
# Build and Push Script for Cargo Tracker
# Jakarta EE application on Payara Server
# =============================================================================

PROJECT_NAME="cargo-tracker"
DOCKERFILE_PATH="Dockerfile"
BUILD_CONTEXT="."

echo "=============================================="
echo "  Cargo Tracker - Docker Build & Push Script"
echo "=============================================="
echo ""

# Sanitize image name: lowercase, replace non-alphanumeric with hyphens, trim hyphens
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "Select container registry:"
echo "  1. AWS ECR (Elastic Container Registry)"
echo "  2. Docker Hub"
echo ""
read -p "Enter choice [1-2]: " REGISTRY_CHOICE

# Prompt for image tag
read -p "Enter image tag [default: latest]: " IMAGE_TAG_INPUT
IMAGE_TAG=$(echo "$IMAGE_TAG_INPUT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

echo ""
echo "Using image name : $IMAGE_NAME"
echo "Using image tag  : $IMAGE_TAG"
echo ""

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ============================================================
  # AWS ECR
  # ============================================================
  echo "--- AWS ECR Configuration ---"
  read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
  read -p "Enter AWS Account ID (12-digit): " AWS_ACCOUNT_ID
  read -p "Enter ECR Repository name [default: $IMAGE_NAME]: " ECR_REPO_INPUT
  ECR_REPO="${ECR_REPO_INPUT:-$IMAGE_NAME}"
  ECR_REPO=$(echo "$ECR_REPO" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9/_-' '-' | sed 's/^-*//;s/-*$//')

  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to AWS ECR..."
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
  if [ $? -ne 0 ]; then
    echo "ERROR: ECR login failed. Check your AWS credentials and region."
    exit 1
  fi
  echo "ECR login successful."

  # Auto-create ECR repository if it doesn't exist
  echo "Checking if ECR repository '$ECR_REPO' exists..."
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    (echo "Repository not found. Creating ECR repository '$ECR_REPO'..." && \
     aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION" && \
     echo "ECR repository created successfully.")

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ============================================================
  # Docker Hub
  # ============================================================
  echo "--- Docker Hub Configuration ---"
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password or access token: " DOCKER_PASSWORD
  echo ""
  read -p "Enter Docker Hub namespace/organization [default: $DOCKER_USERNAME]: " DOCKER_NAMESPACE_INPUT
  DOCKER_NAMESPACE="${DOCKER_NAMESPACE_INPUT:-$DOCKER_USERNAME}"

  REGISTRY_URL="docker.io"
  FULL_IMAGE_NAME="${DOCKER_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Docker Hub..."
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  if [ $? -ne 0 ]; then
    echo "ERROR: Docker Hub login failed. Check your credentials."
    exit 1
  fi
  echo "Docker Hub login successful."

else
  echo "ERROR: Invalid choice. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "=============================================="
echo "  Building Docker Image"
echo "=============================================="
echo "Image: $FULL_IMAGE_NAME"
echo "Dockerfile: $DOCKERFILE_PATH"
echo "Context: $BUILD_CONTEXT"
echo ""

docker build \
  -f "$DOCKERFILE_PATH" \
  -t "$FULL_IMAGE_NAME" \
  "$BUILD_CONTEXT"

if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi
echo ""
echo "Docker image built successfully: $FULL_IMAGE_NAME"

echo ""
echo "=============================================="
echo "  Pushing Docker Image"
echo "=============================================="
docker push "$FULL_IMAGE_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "=============================================="
echo "  Build & Push Complete!"
echo "=============================================="
echo "Image successfully pushed: $FULL_IMAGE_NAME"
echo ""
echo "To deploy to AWS ECS Fargate, run:"
echo "  ./scripts/deploy-image.sh"
echo ""

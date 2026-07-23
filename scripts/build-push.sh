#!/bin/bash
set -e
set -o pipefail

# ============================================================
# build-push.sh - Build and push Docker image for cargo-tracker
# ============================================================

PROJECT_NAME="cargo-tracker"
DOCKERFILE_PATH="Dockerfile"

echo "=============================================="
echo "  cargo-tracker - Docker Build & Push Script"
echo "=============================================="
echo ""

# Sanitize image name: lowercase, replace non-alphanumeric with hyphens, trim hyphens
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Prompt for image tag
read -rp "Enter image tag [latest]: " IMAGE_TAG_INPUT
IMAGE_TAG=$(echo "${IMAGE_TAG_INPUT:-latest}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

echo ""
echo "Select container registry:"
echo "  1. Azure Container Registry (ACR)"
echo "  2. Docker Hub"
read -rp "Enter choice [1 or 2]: " REGISTRY_CHOICE

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # Azure ACR
  read -rp "Enter ACR name (e.g., myregistry): " ACR_NAME
  if [ -z "$ACR_NAME" ]; then
    echo "ERROR: ACR name cannot be empty."
    exit 1
  fi
  REGISTRY="${ACR_NAME}.azurecr.io"
  FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Azure Container Registry: ${ACR_NAME}..."
  az acr login --name "${ACR_NAME}"
  if [ $? -ne 0 ]; then
    echo "ERROR: ACR login failed."
    exit 1
  fi

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # Docker Hub
  read -rp "Enter Docker Hub username: " DOCKER_USERNAME
  if [ -z "$DOCKER_USERNAME" ]; then
    echo "ERROR: Docker Hub username cannot be empty."
    exit 1
  fi
  read -rsp "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  if [ -z "$DOCKER_PASSWORD" ]; then
    echo "ERROR: Docker Hub password cannot be empty."
    exit 1
  fi
  REGISTRY="docker.io"
  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Docker Hub..."
  echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin
  if [ $? -ne 0 ]; then
    echo "ERROR: Docker Hub login failed."
    exit 1
  fi

else
  echo "ERROR: Invalid choice. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "Building Docker image: ${FULL_IMAGE_NAME}"
echo "Using Dockerfile: ${DOCKERFILE_PATH}"
echo "Build context: . (project root)"
echo ""

docker build -f "${DOCKERFILE_PATH}" -t "${FULL_IMAGE_NAME}" .
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi

echo ""
echo "Pushing image: ${FULL_IMAGE_NAME}"
docker push "${FULL_IMAGE_NAME}"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "=============================================="
echo "  SUCCESS: Image pushed successfully!"
echo "  Image: ${FULL_IMAGE_NAME}"
echo "=============================================="
echo ""
echo "Use this image URI in your deployment:"
echo "  ${FULL_IMAGE_NAME}"

#!/bin/bash
set -e
set -o pipefail

# ============================================================
# build-push.sh - Build and Push Docker Image
# Eclipse Cargo Tracker - Jakarta EE Application
# ============================================================

PROJECT_NAME="cargo-tracker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================================"
echo "  Eclipse Cargo Tracker - Docker Build & Push"
echo "============================================================"
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
echo ""
read -rp "Enter choice [1 or 2]: " REGISTRY_CHOICE

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- Azure ACR ----
  echo ""
  read -rp "Enter ACR name (e.g., myregistry): " ACR_NAME
  if [ -z "$ACR_NAME" ]; then
    echo "ERROR: ACR name cannot be empty."
    exit 1
  fi

  ACR_NAME_LOWER=$(echo "$ACR_NAME" | tr '[:upper:]' '[:lower:]')
  REGISTRY="${ACR_NAME_LOWER}.azurecr.io"
  FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Azure Container Registry: ${REGISTRY} ..."
  az acr login --name "$ACR_NAME_LOWER"
  if [ $? -ne 0 ]; then
    echo "ERROR: ACR login failed. Ensure you are logged in with 'az login'."
    exit 1
  fi

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  echo ""
  read -rp "Enter Docker Hub username: " DOCKER_USERNAME
  if [ -z "$DOCKER_USERNAME" ]; then
    echo "ERROR: Docker Hub username cannot be empty."
    exit 1
  fi
  read -rsp "Enter Docker Hub password or access token: " DOCKER_PASSWORD
  echo ""
  if [ -z "$DOCKER_PASSWORD" ]; then
    echo "ERROR: Docker Hub password cannot be empty."
    exit 1
  fi

  REGISTRY="docker.io"
  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Docker Hub ..."
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  if [ $? -ne 0 ]; then
    echo "ERROR: Docker Hub login failed."
    exit 1
  fi

else
  echo "ERROR: Invalid choice. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "------------------------------------------------------------"
echo "  Image Name : ${FULL_IMAGE_NAME}"
echo "  Build Context: ${PROJECT_ROOT}"
echo "------------------------------------------------------------"
echo ""

# Build Docker image
echo "Building Docker image ..."
docker build -f "${PROJECT_ROOT}/Dockerfile" -t "${FULL_IMAGE_NAME}" "${PROJECT_ROOT}"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi
echo "Docker image built successfully: ${FULL_IMAGE_NAME}"

# Push Docker image
echo ""
echo "Pushing Docker image to registry ..."
docker push "${FULL_IMAGE_NAME}"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "============================================================"
echo "  SUCCESS: Image pushed successfully!"
echo "  Image: ${FULL_IMAGE_NAME}"
echo "============================================================"

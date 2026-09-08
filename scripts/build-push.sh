#!/bin/bash
set -e

# ============================================================
# Build and Push Docker Image - cargo-tracker
# ============================================================

PROJECT_NAME="cargo-tracker"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "============================================================"
echo "  Docker Build & Push - ${PROJECT_NAME}"
echo "============================================================"
echo ""

# Prompt for image tag
read -p "Enter image tag (press Enter for 'latest'): " IMAGE_TAG_INPUT
IMAGE_TAG=$(echo "${IMAGE_TAG_INPUT}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "${IMAGE_TAG}" ]; then
  IMAGE_TAG="latest"
fi
echo "Using image tag: ${IMAGE_TAG}"
echo ""

# Prompt for registry type
echo "Select container registry:"
echo "  1. Azure Container Registry (ACR)"
echo "  2. Docker Hub"
read -p "Enter choice (1 or 2): " REGISTRY_CHOICE

if [ "${REGISTRY_CHOICE}" = "1" ]; then
  # Azure ACR
  read -p "Enter ACR name (e.g., myregistry): " ACR_NAME
  ACR_NAME=$(echo "${ACR_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
  if [ -z "${ACR_NAME}" ]; then
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

elif [ "${REGISTRY_CHOICE}" = "2" ]; then
  # Docker Hub
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  read -p "Enter Docker Hub repository (e.g., myorg): " DOCKER_ORG
  if [ -z "${DOCKER_USERNAME}" ] || [ -z "${DOCKER_ORG}" ]; then
    echo "ERROR: Docker Hub username and repository cannot be empty."
    exit 1
  fi
  REGISTRY="docker.io"
  FULL_IMAGE_NAME="${DOCKER_ORG}/${IMAGE_NAME}:${IMAGE_TAG}"

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
echo "Build context: . (repository root)"
echo "------------------------------------------------------------"
docker build -f Dockerfile -t "${FULL_IMAGE_NAME}" .
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi
echo "Docker build successful."
echo ""

echo "Pushing image: ${FULL_IMAGE_NAME}"
echo "------------------------------------------------------------"
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

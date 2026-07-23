#!/bin/bash
set -e
set -o pipefail

PROJECT_NAME="cargo-tracker"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "============================================"
echo "  Docker Build & Push - ${PROJECT_NAME}"
echo "============================================"
echo ""
echo "Select container registry:"
echo "  1. Azure Container Registry (ACR)"
echo "  2. Docker Hub"
echo ""
read -p "Enter choice [1-2]: " REGISTRY_CHOICE

echo ""
read -p "Enter image tag (default: latest): " IMAGE_TAG
IMAGE_TAG=$(echo "${IMAGE_TAG}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "${IMAGE_TAG}" ]; then
  IMAGE_TAG="latest"
fi

if [ "${REGISTRY_CHOICE}" == "1" ]; then
  echo ""
  read -p "Enter Azure ACR name (e.g., myregistry): " ACR_NAME
  ACR_NAME=$(echo "${ACR_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
  if [ -z "${ACR_NAME}" ]; then
    echo "ERROR: ACR name cannot be empty."
    exit 1
  fi
  REGISTRY="${ACR_NAME}.azurecr.io"
  FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Logging in to Azure ACR: ${ACR_NAME}..."
  az acr login --name "${ACR_NAME}"
  if [ $? -ne 0 ]; then
    echo "ERROR: ACR login failed."
    exit 1
  fi

elif [ "${REGISTRY_CHOICE}" == "2" ]; then
  echo ""
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  if [ -z "${DOCKER_USERNAME}" ] || [ -z "${DOCKER_PASSWORD}" ]; then
    echo "ERROR: Docker Hub username and password cannot be empty."
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
  echo "ERROR: Invalid choice. Please select 1 or 2."
  exit 1
fi

echo ""
echo "Building Docker image: ${FULL_IMAGE_NAME}"
docker build -f Dockerfile -t "${FULL_IMAGE_NAME}" .
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi

echo ""
echo "Pushing Docker image: ${FULL_IMAGE_NAME}"
docker push "${FULL_IMAGE_NAME}"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "============================================"
echo "  Build & Push Completed Successfully!"
echo "  Image: ${FULL_IMAGE_NAME}"
echo "============================================"

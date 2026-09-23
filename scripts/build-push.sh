#!/bin/bash
set -e
set -o pipefail

PROJECT_NAME="cargo-tracker"
MODULE_DOCKERFILE="Dockerfile"

IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_NAME" ]; then
  IMAGE_NAME="cargo-tracker"
fi

read -r -p "Enter image tag [latest]: " IMAGE_TAG
IMAGE_TAG=$(echo "${IMAGE_TAG:-latest}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

echo "Select registry type:"
echo "1) Azure ACR"
echo "2) Docker Hub"
read -r -p "Enter selection [1-2]: " REGISTRY_CHOICE

case "$REGISTRY_CHOICE" in
  1)
    read -r -p "Enter Azure Container Registry name (without .azurecr.io): " ACR_NAME
    if [ -z "$ACR_NAME" ]; then
      echo "ACR name is required."
      exit 1
    fi
    az acr login --name "$ACR_NAME"
    REGISTRY_HOST="${ACR_NAME}.azurecr.io"
    FULL_IMAGE_NAME="${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}"
    ;;
  2)
    read -r -p "Enter Docker Hub username or organization: " DOCKER_USERNAME
    if [ -z "$DOCKER_USERNAME" ]; then
      echo "Docker Hub username is required."
      exit 1
    fi
    read -r -s -p "Enter Docker Hub password or access token: " DOCKER_PASSWORD
    echo
    printf '%s' "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
    REGISTRY_HOST="docker.io/${DOCKER_USERNAME}"
    FULL_IMAGE_NAME="${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}"
    ;;
  *)
    echo "Invalid selection."
    exit 1
    ;;
esac

echo "Building image ${FULL_IMAGE_NAME}..."
docker build -f "$MODULE_DOCKERFILE" -t "$FULL_IMAGE_NAME" .

echo "Pushing image ${FULL_IMAGE_NAME}..."
docker push "$FULL_IMAGE_NAME"

echo "Image pushed successfully: ${FULL_IMAGE_NAME}"

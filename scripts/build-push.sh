#!/bin/bash
# ============================================================
# build-push.sh - Build and Push Docker Image
# Eclipse Cargo Tracker - Jakarta EE 10 Application
# Target Platform: GCP GKE
# ============================================================
set -e
set -o pipefail

PROJECT_NAME="cargo-tracker"

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
echo "  1. Google Artifact Registry"
echo "  2. Docker Hub"
read -rp "Enter choice [1 or 2]: " REGISTRY_CHOICE

echo ""

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- Google Artifact Registry ----
  read -rp "Enter GCP Project ID: " GCP_PROJECT
  if [ -z "$GCP_PROJECT" ]; then
    echo "ERROR: GCP Project ID is required."
    exit 1
  fi

  read -rp "Enter GCP Region (e.g., us-central1): " GCP_REGION
  if [ -z "$GCP_REGION" ]; then
    echo "ERROR: GCP Region is required."
    exit 1
  fi

  read -rp "Enter Artifact Registry Repository name [cargo-tracker]: " AR_REPO
  AR_REPO="${AR_REPO:-cargo-tracker}"

  FULL_IMAGE_NAME="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Authenticating with Google Artifact Registry..."
  gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet
  echo "Authentication configured."

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  read -rp "Enter Docker Hub username: " DOCKER_USERNAME
  if [ -z "$DOCKER_USERNAME" ]; then
    echo "ERROR: Docker Hub username is required."
    exit 1
  fi

  read -rsp "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  if [ -z "$DOCKER_PASSWORD" ]; then
    echo "ERROR: Docker Hub password/token is required."
    exit 1
  fi

  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Authenticating with Docker Hub..."
  echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin
  echo "Docker Hub login successful."

else
  echo "ERROR: Invalid choice. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "------------------------------------------------------------"
echo "  Image Name : ${FULL_IMAGE_NAME}"
echo "------------------------------------------------------------"
echo ""

# Build Docker image (context is repository root)
echo "Building Docker image..."
docker build -f Dockerfile -t "${FULL_IMAGE_NAME}" .
echo "Docker image built successfully."

echo ""
echo "Pushing Docker image to registry..."
docker push "${FULL_IMAGE_NAME}"
echo "Docker image pushed successfully."

echo ""
echo "============================================================"
echo "  Build & Push Complete!"
echo "  Image: ${FULL_IMAGE_NAME}"
echo "============================================================"

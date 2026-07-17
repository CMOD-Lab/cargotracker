#!/bin/bash
set -e
set -o pipefail

# ============================================================
# build-push.sh - Build and Push Docker Image for cargo-tracker
# Target Platform: GCP GKE
# ============================================================

PROJECT_NAME="cargo-tracker"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "============================================================"
echo "  cargo-tracker - Docker Build & Push"
echo "============================================================"
echo ""

# Prompt for image tag
read -p "Enter image tag (press Enter for 'latest'): " IMAGE_TAG
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi
echo "Using image tag: $IMAGE_TAG"
echo ""

# Registry selection
echo "Select container registry:"
echo "  1. Google Artifact Registry"
echo "  2. Docker Hub"
read -p "Enter choice (1 or 2): " REGISTRY_CHOICE
echo ""

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- Google Artifact Registry ----
  echo "--- Google Artifact Registry Setup ---"
  read -p "Enter GCP Project ID: " GCP_PROJECT
  read -p "Enter GCP Region (e.g., us-central1): " GCP_REGION
  read -p "Enter Artifact Registry repository name: " AR_REPO

  if [ -z "$GCP_PROJECT" ] || [ -z "$GCP_REGION" ] || [ -z "$AR_REPO" ]; then
    echo "ERROR: GCP Project ID, Region, and Repository name are required."
    exit 1
  fi

  FULL_IMAGE_NAME="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Authenticating with Google Artifact Registry..."
  gcloud auth login --quiet
  gcloud config set project "$GCP_PROJECT"
  gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet
  echo "Authentication successful."

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  echo "--- Docker Hub Setup ---"
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""

  if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
    echo "ERROR: Docker Hub username and password are required."
    exit 1
  fi

  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo ""
  echo "Authenticating with Docker Hub..."
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  echo "Authentication successful."

else
  echo "ERROR: Invalid registry choice. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "Building Docker image: $FULL_IMAGE_NAME"
echo "Build context: . (repository root)"
docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi
echo "Docker image built successfully."

echo ""
echo "Pushing Docker image: $FULL_IMAGE_NAME"
docker push "$FULL_IMAGE_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "============================================================"
echo "  SUCCESS: Image pushed successfully!"
echo "  Image: $FULL_IMAGE_NAME"
echo "============================================================"

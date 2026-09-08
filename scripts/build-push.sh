#!/bin/bash
set -e
set -o pipefail

# ============================================================
# build-push.sh - Build and Push Docker Image for cargo-tracker
# ============================================================

PROJECT_NAME="cargo-tracker"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=============================================="
echo "  cargo-tracker - Docker Build & Push Script"
echo "=============================================="
echo ""

# Prompt for image tag
read -p "Enter image tag (press Enter for 'latest'): " IMAGE_TAG
IMAGE_TAG=$(echo "${IMAGE_TAG:-latest}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi
echo "Using image tag: $IMAGE_TAG"
echo ""

# Prompt for registry type
echo "Select container registry:"
echo "  1. Google Artifact Registry"
echo "  2. Docker Hub"
read -p "Enter choice (1 or 2): " REGISTRY_CHOICE
echo ""

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- Google Artifact Registry ----
  read -p "Enter GCP Project ID: " GCP_PROJECT
  read -p "Enter GCP Region (e.g., us-central1): " GCP_REGION
  read -p "Enter Artifact Registry repository name (e.g., cargo-tracker-repo): " AR_REPO

  REGISTRY="${GCP_REGION}-docker.pkg.dev"
  FULL_IMAGE_NAME="${REGISTRY}/${GCP_PROJECT}/${AR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

  echo "Authenticating with Google Artifact Registry..."
  gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet
  echo "Authentication successful."

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""

  FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

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
echo "----------------------------------------------"

docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .

echo ""
echo "Build successful!"
echo "Pushing image: $FULL_IMAGE_NAME"
echo "----------------------------------------------"

docker push "$FULL_IMAGE_NAME"

echo ""
echo "=============================================="
echo "  Image pushed successfully!"
echo "  Image: $FULL_IMAGE_NAME"
echo "=============================================="

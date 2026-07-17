#!/bin/bash
set -e

# ============================================================
# build-push.sh - Build and push Docker image for cargo-tracker
# Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
# ============================================================

PROJECT_NAME="cargo-tracker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================================"
echo "  Eclipse Cargo Tracker - Docker Build & Push"
echo "============================================================"
echo ""

# Sanitize image name
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Prompt for image tag
read -p "Enter image tag [latest]: " IMAGE_TAG
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo ""
echo "Select container registry:"
echo "  1. Google Artifact Registry"
echo "  2. Docker Hub"
read -p "Enter choice [1]: " REGISTRY_CHOICE
REGISTRY_CHOICE="${REGISTRY_CHOICE:-1}"

if [ "$REGISTRY_CHOICE" = "1" ]; then
    echo ""
    echo "--- Google Artifact Registry ---"
    read -p "Enter GCP Project ID: " GCP_PROJECT
    if [ -z "$GCP_PROJECT" ]; then
        echo "ERROR: GCP Project ID is required."
        exit 1
    fi
    read -p "Enter GCP Region (e.g. us-central1): " GCP_REGION
    GCP_REGION="${GCP_REGION:-us-central1}"
    read -p "Enter Artifact Registry repository name [cargo-tracker]: " AR_REPO
    AR_REPO="${AR_REPO:-cargo-tracker}"

    FULL_IMAGE_NAME="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

    echo ""
    echo "Authenticating with Google Artifact Registry..."
    gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet
    if [ $? -ne 0 ]; then
        echo "ERROR: Artifact Registry authentication failed."
        exit 1
    fi

elif [ "$REGISTRY_CHOICE" = "2" ]; then
    echo ""
    echo "--- Docker Hub ---"
    read -p "Enter Docker Hub username: " DOCKER_USERNAME
    if [ -z "$DOCKER_USERNAME" ]; then
        echo "ERROR: Docker Hub username is required."
        exit 1
    fi
    read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
    echo ""
    if [ -z "$DOCKER_PASSWORD" ]; then
        echo "ERROR: Docker Hub password is required."
        exit 1
    fi

    FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

    echo ""
    echo "Authenticating with Docker Hub..."
    echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
    if [ $? -ne 0 ]; then
        echo "ERROR: Docker Hub authentication failed."
        exit 1
    fi

else
    echo "ERROR: Invalid registry choice."
    exit 1
fi

echo ""
echo "Building Docker image: ${FULL_IMAGE_NAME}"
echo "Build context: ${PROJECT_ROOT}"
echo ""

docker build -f "${PROJECT_ROOT}/Dockerfile" -t "${FULL_IMAGE_NAME}" "${PROJECT_ROOT}"
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
echo "============================================================"
echo "  SUCCESS: Image pushed successfully!"
echo "  Image: ${FULL_IMAGE_NAME}"
echo "============================================================"
echo ""
echo "Use this image URI in deploy-image.sh:"
echo "  ${FULL_IMAGE_NAME}"

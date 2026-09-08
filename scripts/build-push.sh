#!/bin/bash
# =============================================================================
# build-push.sh  –  Build and push the cargo-tracker Docker image
# Supports: Azure Container Registry (ACR) and Docker Hub
# Usage   : bash scripts/build-push.sh
# =============================================================================
set -e
set -o pipefail

PROJECT_NAME="cargo-tracker"
DOCKERFILE_PATH="Dockerfile"

# ---------------------------------------------------------------------------
# Sanitise image name: lowercase, replace non-alphanumeric with hyphens,
# trim leading/trailing hyphens.
# ---------------------------------------------------------------------------
IMAGE_NAME=$(echo "${PROJECT_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=============================================="
echo "  Eclipse Cargo Tracker – Docker Build & Push"
echo "=============================================="
echo ""
echo "Project : ${PROJECT_NAME}"
echo "Image   : ${IMAGE_NAME}"
echo ""

# ---------------------------------------------------------------------------
# Prompt for image tag
# ---------------------------------------------------------------------------
read -rp "Enter image tag [latest]: " IMAGE_TAG
IMAGE_TAG="${IMAGE_TAG:-latest}"
# Sanitise tag
IMAGE_TAG=$(echo "${IMAGE_TAG}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
IMAGE_TAG="${IMAGE_TAG:-latest}"
echo "Tag     : ${IMAGE_TAG}"
echo ""

# ---------------------------------------------------------------------------
# Registry selection
# ---------------------------------------------------------------------------
echo "Select container registry:"
echo "  1) Azure Container Registry (ACR)"
echo "  2) Docker Hub"
read -rp "Enter choice [1]: " REGISTRY_CHOICE
REGISTRY_CHOICE="${REGISTRY_CHOICE:-1}"

if [ "${REGISTRY_CHOICE}" = "1" ]; then
    # ---- Azure ACR ----
    echo ""
    echo "--- Azure Container Registry ---"
    read -rp "Enter ACR name (e.g. myregistry): " ACR_NAME
    if [ -z "${ACR_NAME}" ]; then
        echo "ERROR: ACR name cannot be empty." >&2
        exit 1
    fi

    REGISTRY="${ACR_NAME}.azurecr.io"
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

    echo ""
    echo "Logging in to ACR: ${ACR_NAME} ..."
    az acr login --name "${ACR_NAME}"
    if [ $? -ne 0 ]; then
        echo "ERROR: ACR login failed." >&2
        exit 1
    fi

elif [ "${REGISTRY_CHOICE}" = "2" ]; then
    # ---- Docker Hub ----
    echo ""
    echo "--- Docker Hub ---"
    read -rp "Enter Docker Hub username: " DOCKER_USERNAME
    if [ -z "${DOCKER_USERNAME}" ]; then
        echo "ERROR: Docker Hub username cannot be empty." >&2
        exit 1
    fi
    read -rsp "Enter Docker Hub password/token: " DOCKER_PASSWORD
    echo ""
    if [ -z "${DOCKER_PASSWORD}" ]; then
        echo "ERROR: Docker Hub password cannot be empty." >&2
        exit 1
    fi

    FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

    echo ""
    echo "Logging in to Docker Hub ..."
    echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin
    if [ $? -ne 0 ]; then
        echo "ERROR: Docker Hub login failed." >&2
        exit 1
    fi

else
    echo "ERROR: Invalid registry choice '${REGISTRY_CHOICE}'." >&2
    exit 1
fi

echo ""
echo "Full image name: ${FULL_IMAGE_NAME}"
echo ""

# ---------------------------------------------------------------------------
# Build Docker image
# ---------------------------------------------------------------------------
echo "Building Docker image ..."
docker build -f "${DOCKERFILE_PATH}" -t "${FULL_IMAGE_NAME}" .
if [ $? -ne 0 ]; then
    echo "ERROR: Docker build failed." >&2
    exit 1
fi
echo "Build successful."
echo ""

# ---------------------------------------------------------------------------
# Push Docker image
# ---------------------------------------------------------------------------
echo "Pushing image to registry ..."
docker push "${FULL_IMAGE_NAME}"
if [ $? -ne 0 ]; then
    echo "ERROR: Docker push failed." >&2
    exit 1
fi

echo ""
echo "=============================================="
echo "  Image pushed successfully!"
echo "  ${FULL_IMAGE_NAME}"
echo "=============================================="

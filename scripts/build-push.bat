@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: build-push.bat - Build and Push Docker Image for cargo-tracker
:: ============================================================

set PROJECT_NAME=cargo-tracker
set IMAGE_NAME=cargo-tracker

echo ==============================================
echo   cargo-tracker - Docker Build ^& Push Script
echo ==============================================
echo.

:: Prompt for image tag
set /p IMAGE_TAG="Enter image tag (press Enter for 'latest'): "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
echo Using image tag: !IMAGE_TAG!
echo.

:: Prompt for registry type
echo Select container registry:
echo   1. Google Artifact Registry
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice (1 or 2): "
echo.

if "!REGISTRY_CHOICE!"=="1" goto artifact_registry
if "!REGISTRY_CHOICE!"=="2" goto docker_hub
echo ERROR: Invalid registry choice. Please enter 1 or 2.
exit /b 1

:artifact_registry
set /p GCP_PROJECT="Enter GCP Project ID: "
set /p GCP_REGION="Enter GCP Region (e.g., us-central1): "
set /p AR_REPO="Enter Artifact Registry repository name (e.g., cargo-tracker-repo): "

set FULL_IMAGE_NAME=!GCP_REGION!-docker.pkg.dev/!GCP_PROJECT!/!AR_REPO!/!IMAGE_NAME!:!IMAGE_TAG!

echo Authenticating with Google Artifact Registry...
gcloud auth configure-docker !GCP_REGION!-docker.pkg.dev --quiet
if !ERRORLEVEL! neq 0 (
    echo ERROR: Artifact Registry authentication failed.
    exit /b 1
)
echo Authentication successful.
goto build_image

:docker_hub
set /p DOCKER_USERNAME="Enter Docker Hub username: "
set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "

set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!

echo Authenticating with Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub authentication failed.
    exit /b 1
)
echo Authentication successful.
goto build_image

:build_image
echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Build context: . (repository root)
echo ----------------------------------------------

docker build -f Dockerfile -t "!FULL_IMAGE_NAME!" .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)

echo.
echo Build successful!
echo Pushing image: !FULL_IMAGE_NAME!
echo ----------------------------------------------

docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   Image pushed successfully!
echo   Image: !FULL_IMAGE_NAME!
echo ==============================================

endlocal

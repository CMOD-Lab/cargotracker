@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM build-push.bat - Build and push Docker image for cargo-tracker
REM Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
REM ============================================================

set PROJECT_NAME=cargo-tracker
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..

echo ============================================================
echo   Eclipse Cargo Tracker - Docker Build and Push
echo ============================================================
echo.

REM Sanitize image name (lowercase, hyphens only)
set IMAGE_NAME=cargo-tracker

REM Prompt for image tag
set /p IMAGE_TAG="Enter image tag [latest]: "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

echo.
echo Select container registry:
echo   1. Google Artifact Registry
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice [1]: "
if "!REGISTRY_CHOICE!"=="" set REGISTRY_CHOICE=1

if "!REGISTRY_CHOICE!"=="1" goto artifact_registry
if "!REGISTRY_CHOICE!"=="2" goto docker_hub
echo ERROR: Invalid registry choice.
exit /b 1

:artifact_registry
echo.
echo --- Google Artifact Registry ---
set /p GCP_PROJECT="Enter GCP Project ID: "
if "!GCP_PROJECT!"=="" (
    echo ERROR: GCP Project ID is required.
    exit /b 1
)
set /p GCP_REGION="Enter GCP Region (e.g. us-central1): "
if "!GCP_REGION!"=="" set GCP_REGION=us-central1
set /p AR_REPO="Enter Artifact Registry repository name [cargo-tracker]: "
if "!AR_REPO!"=="" set AR_REPO=cargo-tracker

set FULL_IMAGE_NAME=!GCP_REGION!-docker.pkg.dev/!GCP_PROJECT!/!AR_REPO!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Authenticating with Google Artifact Registry...
gcloud auth configure-docker !GCP_REGION!-docker.pkg.dev --quiet
if !ERRORLEVEL! neq 0 (
    echo ERROR: Artifact Registry authentication failed.
    exit /b 1
)
goto build_image

:docker_hub
echo.
echo --- Docker Hub ---
set /p DOCKER_USERNAME="Enter Docker Hub username: "
if "!DOCKER_USERNAME!"=="" (
    echo ERROR: Docker Hub username is required.
    exit /b 1
)
set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
if "!DOCKER_PASSWORD!"=="" (
    echo ERROR: Docker Hub password is required.
    exit /b 1
)

set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Authenticating with Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub authentication failed.
    exit /b 1
)
goto build_image

:build_image
echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Build context: !PROJECT_ROOT!
echo.

docker build -f "!PROJECT_ROOT!\Dockerfile" -t "!FULL_IMAGE_NAME!" "!PROJECT_ROOT!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)

echo.
echo Pushing image: !FULL_IMAGE_NAME!
docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ============================================================
echo   SUCCESS: Image pushed successfully!
echo   Image: !FULL_IMAGE_NAME!
echo ============================================================
echo.
echo Use this image URI in deploy-image.bat:
echo   !FULL_IMAGE_NAME!

endlocal

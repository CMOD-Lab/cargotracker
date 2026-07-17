@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM build-push.bat - Build and Push Docker Image for cargo-tracker
REM Target Platform: GCP GKE
REM ============================================================

set PROJECT_NAME=cargo-tracker
set IMAGE_NAME=cargo-tracker

echo ============================================================
echo   cargo-tracker - Docker Build ^& Push
echo ============================================================
echo.

REM Prompt for image tag
set /p IMAGE_TAG="Enter image tag (press Enter for 'latest'): "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
echo Using image tag: !IMAGE_TAG!
echo.

REM Registry selection
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
echo --- Google Artifact Registry Setup ---
set /p GCP_PROJECT="Enter GCP Project ID: "
set /p GCP_REGION="Enter GCP Region (e.g., us-central1): "
set /p AR_REPO="Enter Artifact Registry repository name: "

if "!GCP_PROJECT!"=="" (
  echo ERROR: GCP Project ID is required.
  exit /b 1
)
if "!GCP_REGION!"=="" (
  echo ERROR: GCP Region is required.
  exit /b 1
)
if "!AR_REPO!"=="" (
  echo ERROR: Repository name is required.
  exit /b 1
)

set FULL_IMAGE_NAME=!GCP_REGION!-docker.pkg.dev/!GCP_PROJECT!/!AR_REPO!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Authenticating with Google Artifact Registry...
gcloud auth login --quiet
if !ERRORLEVEL! neq 0 (
  echo ERROR: gcloud auth login failed.
  exit /b 1
)
gcloud config set project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
  echo ERROR: gcloud config set project failed.
  exit /b 1
)
gcloud auth configure-docker !GCP_REGION!-docker.pkg.dev --quiet
if !ERRORLEVEL! neq 0 (
  echo ERROR: Artifact Registry login failed.
  exit /b 1
)
echo Authentication successful.
goto build_image

:docker_hub
echo --- Docker Hub Setup ---
set /p DOCKER_USERNAME="Enter Docker Hub username: "
set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "

if "!DOCKER_USERNAME!"=="" (
  echo ERROR: Docker Hub username is required.
  exit /b 1
)
if "!DOCKER_PASSWORD!"=="" (
  echo ERROR: Docker Hub password is required.
  exit /b 1
)

set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Authenticating with Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
  echo ERROR: Docker Hub login failed.
  exit /b 1
)
echo Authentication successful.
goto build_image

:build_image
echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Build context: . (repository root)
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
  echo ERROR: Docker build failed.
  exit /b 1
)
echo Docker image built successfully.

echo.
echo Pushing Docker image: !FULL_IMAGE_NAME!
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
  echo ERROR: Docker push failed.
  exit /b 1
)

echo.
echo ============================================================
echo   SUCCESS: Image pushed successfully!
echo   Image: !FULL_IMAGE_NAME!
echo ============================================================

endlocal

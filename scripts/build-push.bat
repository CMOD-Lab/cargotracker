@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM build-push.bat - Build and Push Docker Image for Eclipse Cargo Tracker
REM Target Platform: GCP GKE
REM =============================================================================

set PROJECT_NAME=cargo-tracker

echo ==============================================
echo  Eclipse Cargo Tracker - Build ^& Push Script
echo ==============================================
echo.

REM Sanitize image name using PowerShell
for /f "delims=" %%i in ('powershell -Command "\"cargo-tracker\" -replace \"[^a-z0-9]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set IMAGE_NAME=%%i

echo Select container registry:
echo   1. Google Artifact Registry
echo   2. Docker Hub
echo.
set /p REGISTRY_CHOICE="Enter choice [1 or 2]: "

if "!REGISTRY_CHOICE!"=="1" goto artifact_registry
if "!REGISTRY_CHOICE!"=="2" goto docker_hub
echo ERROR: Invalid choice. Please enter 1 or 2.
exit /b 1

:artifact_registry
echo.
set /p GCP_PROJECT="Enter GCP Project ID: "
if "!GCP_PROJECT!"=="" (
    echo ERROR: GCP Project ID cannot be empty.
    exit /b 1
)

set /p GCP_REGION="Enter GCP Region (e.g., us-central1): "
if "!GCP_REGION!"=="" (
    echo ERROR: GCP Region cannot be empty.
    exit /b 1
)

set /p AR_REPO="Enter Artifact Registry Repository name (e.g., my-repo): "
if "!AR_REPO!"=="" (
    echo ERROR: Repository name cannot be empty.
    exit /b 1
)

set /p IMAGE_TAG="Enter image tag [default: latest]: "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

for /f "delims=" %%i in ('powershell -Command "\"!IMAGE_TAG!\" -replace \"[^a-z0-9._-]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set IMAGE_TAG=%%i
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

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
set /p DOCKER_USERNAME="Enter Docker Hub username: "
if "!DOCKER_USERNAME!"=="" (
    echo ERROR: Docker Hub username cannot be empty.
    exit /b 1
)

set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
if "!DOCKER_PASSWORD!"=="" (
    echo ERROR: Docker Hub password cannot be empty.
    exit /b 1
)

set /p IMAGE_TAG="Enter image tag [default: latest]: "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

for /f "delims=" %%i in ('powershell -Command "\"!IMAGE_TAG!\" -replace \"[^a-z0-9._-]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set IMAGE_TAG=%%i
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

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
echo Build context: %CD%
echo.

docker build -f Dockerfile -t "!FULL_IMAGE_NAME!" .
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
echo ==============================================
echo  SUCCESS: Image pushed successfully!
echo  Image: !FULL_IMAGE_NAME!
echo ==============================================
echo.
echo Next step: Run scripts\deploy-image.bat to deploy to GKE.

endlocal

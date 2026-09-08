@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM build-push.bat - Build and Push Docker Image (Windows)
REM Eclipse Cargo Tracker - Jakarta EE 10 Application
REM Target Platform: GCP GKE
REM ============================================================

set PROJECT_NAME=cargo-tracker

echo ============================================================
echo   Eclipse Cargo Tracker - Docker Build ^& Push
echo ============================================================
echo.

REM Sanitize image name using PowerShell
for /f "delims=" %%i in ('powershell -Command "\"cargo-tracker\" -replace '[^a-z0-9]','-' -replace '^-+','' -replace '-+$',''"') do set IMAGE_NAME=%%i

REM Prompt for image tag
set /p IMAGE_TAG_INPUT="Enter image tag [latest]: "
if "!IMAGE_TAG_INPUT!"=="" set IMAGE_TAG_INPUT=latest
for /f "delims=" %%i in ('powershell -Command "\"!IMAGE_TAG_INPUT!\" -replace '[^a-z0-9._-]','-' -replace '^-+','' -replace '-+$','' -replace '  +',' '"') do set IMAGE_TAG=%%i
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

echo.
echo Select container registry:
echo   1. Google Artifact Registry
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice [1 or 2]: "

echo.

if "!REGISTRY_CHOICE!"=="1" (
    REM ---- Google Artifact Registry ----
    set /p GCP_PROJECT="Enter GCP Project ID: "
    if "!GCP_PROJECT!"=="" (
        echo ERROR: GCP Project ID is required.
        exit /b 1
    )

    set /p GCP_REGION="Enter GCP Region (e.g., us-central1): "
    if "!GCP_REGION!"=="" (
        echo ERROR: GCP Region is required.
        exit /b 1
    )

    set /p AR_REPO="Enter Artifact Registry Repository name [cargo-tracker]: "
    if "!AR_REPO!"=="" set AR_REPO=cargo-tracker

    set FULL_IMAGE_NAME=!GCP_REGION!-docker.pkg.dev/!GCP_PROJECT!/!AR_REPO!/!IMAGE_NAME!:!IMAGE_TAG!

    echo.
    echo Authenticating with Google Artifact Registry...
    gcloud auth configure-docker !GCP_REGION!-docker.pkg.dev --quiet
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Artifact Registry authentication failed.
        exit /b 1
    )
    echo Authentication configured.

) else if "!REGISTRY_CHOICE!"=="2" (
    REM ---- Docker Hub ----
    set /p DOCKER_USERNAME="Enter Docker Hub username: "
    if "!DOCKER_USERNAME!"=="" (
        echo ERROR: Docker Hub username is required.
        exit /b 1
    )

    set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
    if "!DOCKER_PASSWORD!"=="" (
        echo ERROR: Docker Hub password/token is required.
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
    echo Docker Hub login successful.

) else (
    echo ERROR: Invalid choice. Please enter 1 or 2.
    exit /b 1
)

echo.
echo ------------------------------------------------------------
echo   Image Name : !FULL_IMAGE_NAME!
echo ------------------------------------------------------------
echo.

REM Build Docker image (context is repository root)
echo Building Docker image...
docker build -f Dockerfile -t "!FULL_IMAGE_NAME!" .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo Docker image built successfully.

echo.
echo Pushing Docker image to registry...
docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)
echo Docker image pushed successfully.

echo.
echo ============================================================
echo   Build ^& Push Complete!
echo   Image: !FULL_IMAGE_NAME!
echo ============================================================

endlocal

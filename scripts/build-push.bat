@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM build-push.bat - Build and Push Docker Image for CareTracker (cargo-tracker)
REM =============================================================================

set "PROJECT_NAME=cargo-tracker"
set "IMAGE_NAME=cargo-tracker"

echo ==============================================
echo   CareTracker Application - Build ^& Push
echo ==============================================
echo.

REM Prompt for image tag
set /p "IMAGE_TAG_INPUT=Enter image tag [latest]: "
if "!IMAGE_TAG_INPUT!"=="" (
    set "IMAGE_TAG=latest"
) else (
    set "IMAGE_TAG=!IMAGE_TAG_INPUT!"
)
echo Using image tag: !IMAGE_TAG!
echo.

REM Registry selection
echo Select container registry:
echo   1. AWS ECR (Elastic Container Registry)
echo   2. Docker Hub
set /p "REGISTRY_CHOICE=Enter choice [1]: "
if "!REGISTRY_CHOICE!"=="" set "REGISTRY_CHOICE=1"

if "!REGISTRY_CHOICE!"=="1" goto :ecr_setup
if "!REGISTRY_CHOICE!"=="2" goto :dockerhub_setup
echo ERROR: Invalid registry choice.
exit /b 1

:ecr_setup
echo.
echo --- AWS ECR Configuration ---
set /p "AWS_REGION=Enter AWS Region [us-east-1]: "
if "!AWS_REGION!"=="" set "AWS_REGION=us-east-1"
set /p "AWS_ACCOUNT_ID=Enter AWS Account ID (leave blank to auto-detect): "
if "!AWS_ACCOUNT_ID!"=="" (
    echo Fetching AWS Account ID...
    for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text 2^>^&1') do set "AWS_ACCOUNT_ID=%%i"
    echo Account ID: !AWS_ACCOUNT_ID!
)
set /p "ECR_REPO_INPUT=Enter ECR repository name [!IMAGE_NAME!]: "
if "!ECR_REPO_INPUT!"=="" (
    set "ECR_REPO=!IMAGE_NAME!"
) else (
    set "ECR_REPO=!ECR_REPO_INPUT!"
)
set "REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com"
set "FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!"

echo.
echo Logging in to AWS ECR...
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ERROR: ECR login failed.
    exit /b 1
)

echo Checking/creating ECR repository: !ECR_REPO! ...
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECR repository.
        exit /b 1
    )
)
echo ECR repository ready.
goto :build_image

:dockerhub_setup
echo.
echo --- Docker Hub Configuration ---
set /p "DOCKER_USERNAME=Enter Docker Hub username: "
set /p "DOCKER_PASSWORD=Enter Docker Hub password/token: "
set /p "DOCKER_REPO_INPUT=Enter Docker Hub repository [!DOCKER_USERNAME!/!IMAGE_NAME!]: "
if "!DOCKER_REPO_INPUT!"=="" (
    set "DOCKER_REPO=!DOCKER_USERNAME!/!IMAGE_NAME!"
) else (
    set "DOCKER_REPO=!DOCKER_REPO_INPUT!"
)
set "FULL_IMAGE_NAME=!DOCKER_REPO!:!IMAGE_TAG!"

echo.
echo Logging in to Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub login failed.
    exit /b 1
)
goto :build_image

:build_image
echo.
echo ==============================================
echo Building Docker image...
echo   Image: !FULL_IMAGE_NAME!
echo   Context: . (project root)
echo ==============================================

docker build -f Dockerfile -t "!FULL_IMAGE_NAME!" .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo Docker build successful.

echo.
echo Pushing image: !FULL_IMAGE_NAME! ...
docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo SUCCESS: Image pushed successfully!
echo   Full image URI: !FULL_IMAGE_NAME!
echo   Use this URI in your ECS task definition.
echo ==============================================

endlocal

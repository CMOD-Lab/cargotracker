@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: Build and Push Script for Cargo Tracker (Windows)
:: Jakarta EE application on Payara Server
:: =============================================================================

set "PROJECT_NAME=cargo-tracker"
set "DOCKERFILE_PATH=Dockerfile"
set "BUILD_CONTEXT=."

echo ==============================================
echo   Cargo Tracker - Docker Build ^& Push Script
echo ==============================================
echo.

:: Sanitize image name using PowerShell
for /f "delims=" %%i in ('powershell -Command "\"cargo-tracker\" -replace \"[^a-z0-9]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set "IMAGE_NAME=%%i"
if "!IMAGE_NAME!"=="" set "IMAGE_NAME=cargo-tracker"

echo Select container registry:
echo   1. AWS ECR (Elastic Container Registry)
echo   2. Docker Hub
echo.
set /p "REGISTRY_CHOICE=Enter choice [1-2]: "

:: Prompt for image tag
set /p "IMAGE_TAG_INPUT=Enter image tag [default: latest]: "
if "!IMAGE_TAG_INPUT!"=="" (
    set "IMAGE_TAG=latest"
) else (
    for /f "delims=" %%t in ('powershell -Command "\"!IMAGE_TAG_INPUT!\" -replace \"[^a-z0-9._-]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set "IMAGE_TAG=%%t"
    if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
)

echo.
echo Using image name : !IMAGE_NAME!
echo Using image tag  : !IMAGE_TAG!
echo.

if "!REGISTRY_CHOICE!"=="1" (
    :: ============================================================
    :: AWS ECR
    :: ============================================================
    echo --- AWS ECR Configuration ---
    set /p "AWS_REGION=Enter AWS Region (e.g., us-east-1): "
    set /p "AWS_ACCOUNT_ID=Enter AWS Account ID (12-digit): "
    set /p "ECR_REPO_INPUT=Enter ECR Repository name [default: !IMAGE_NAME!]: "
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
        echo ERROR: ECR login failed. Check your AWS credentials and region.
        exit /b 1
    )
    echo ECR login successful.

    :: Auto-create ECR repository if it doesn't exist
    echo Checking if ECR repository '!ECR_REPO!' exists...
    aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        echo Repository not found. Creating ECR repository '!ECR_REPO!'...
        aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
        if !ERRORLEVEL! neq 0 (
            echo ERROR: Failed to create ECR repository.
            exit /b 1
        )
        echo ECR repository created successfully.
    )

) else if "!REGISTRY_CHOICE!"=="2" (
    :: ============================================================
    :: Docker Hub
    :: ============================================================
    echo --- Docker Hub Configuration ---
    set /p "DOCKER_USERNAME=Enter Docker Hub username: "
    set /p "DOCKER_PASSWORD=Enter Docker Hub password or access token: "
    set /p "DOCKER_NAMESPACE_INPUT=Enter Docker Hub namespace/organization [default: !DOCKER_USERNAME!]: "
    if "!DOCKER_NAMESPACE_INPUT!"=="" (
        set "DOCKER_NAMESPACE=!DOCKER_USERNAME!"
    ) else (
        set "DOCKER_NAMESPACE=!DOCKER_NAMESPACE_INPUT!"
    )

    set "REGISTRY_URL=docker.io"
    set "FULL_IMAGE_NAME=!DOCKER_NAMESPACE!/!IMAGE_NAME!:!IMAGE_TAG!"

    echo.
    echo Logging in to Docker Hub...
    echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Docker Hub login failed. Check your credentials.
        exit /b 1
    )
    echo Docker Hub login successful.

) else (
    echo ERROR: Invalid choice. Please enter 1 or 2.
    exit /b 1
)

echo.
echo ==============================================
echo   Building Docker Image
echo ==============================================
echo Image: !FULL_IMAGE_NAME!
echo Dockerfile: !DOCKERFILE_PATH!
echo Context: !BUILD_CONTEXT!
echo.

docker build -f "!DOCKERFILE_PATH!" -t "!FULL_IMAGE_NAME!" "!BUILD_CONTEXT!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo.
echo Docker image built successfully: !FULL_IMAGE_NAME!

echo.
echo ==============================================
echo   Pushing Docker Image
echo ==============================================
docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   Build ^& Push Complete!
echo ==============================================
echo Image successfully pushed: !FULL_IMAGE_NAME!
echo.
echo To deploy to AWS ECS Fargate, run:
echo   scripts\deploy-image.bat
echo.

endlocal

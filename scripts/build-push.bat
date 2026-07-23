@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM build-push.bat - Build and push Docker image for cargo-tracker (Windows)
REM Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
REM =============================================================================

set PROJECT_NAME=cargo-tracker
set DOCKERFILE_PATH=Dockerfile
set BUILD_CONTEXT=.

echo ==============================================
echo   cargo-tracker - Docker Build ^& Push Script
echo ==============================================
echo.

REM Sanitize image name using PowerShell
for /f "delims=" %%i in ('powershell -Command "\"cargo-tracker\" -replace \"[^a-z0-9]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set IMAGE_NAME=%%i
echo Image name: !IMAGE_NAME!

REM Prompt for image tag
set /p IMAGE_TAG_INPUT="Enter image tag [latest]: "
if "!IMAGE_TAG_INPUT!"=="" set IMAGE_TAG_INPUT=latest
for /f "delims=" %%i in ('powershell -Command "\"!IMAGE_TAG_INPUT!\" -replace \"[^a-z0-9._-]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set IMAGE_TAG=%%i
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
echo Image tag: !IMAGE_TAG!
echo.

REM Select registry type
echo Select container registry:
echo   1. AWS ECR (Elastic Container Registry)
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice [1]: "
if "!REGISTRY_CHOICE!"=="" set REGISTRY_CHOICE=1

if "!REGISTRY_CHOICE!"=="1" goto ECR_SETUP
if "!REGISTRY_CHOICE!"=="2" goto DOCKERHUB_SETUP
echo ERROR: Invalid registry choice. Please enter 1 or 2.
exit /b 1

:ECR_SETUP
echo.
echo --- AWS ECR Configuration ---
set /p AWS_REGION="Enter AWS Region [us-east-1]: "
if "!AWS_REGION!"=="" set AWS_REGION=us-east-1

set /p ECR_REPO_INPUT="Enter ECR repository name [!IMAGE_NAME!]: "
if "!ECR_REPO_INPUT!"=="" set ECR_REPO=!IMAGE_NAME!
if not "!ECR_REPO_INPUT!"=="" set ECR_REPO=!ECR_REPO_INPUT!

echo Retrieving AWS Account ID...
for /f "delims=" %%i in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%i
if "!ACCOUNT_ID!"=="" (
    echo ERROR: Could not retrieve AWS Account ID. Ensure AWS CLI is configured.
    exit /b 1
)
echo AWS Account ID: !ACCOUNT_ID!

set REGISTRY_URL=!ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com
set FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!

echo.
echo Logging in to AWS ECR...
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ERROR: ECR login failed.
    exit /b 1
)
echo ECR login successful.

echo Checking if ECR repository exists...
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository: !ECR_REPO!
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECR repository.
        exit /b 1
    )
)
echo ECR repository ready.
goto BUILD_IMAGE

:DOCKERHUB_SETUP
echo.
echo --- Docker Hub Configuration ---
set /p DOCKER_USERNAME="Enter Docker Hub username: "
set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
set /p DOCKER_NAMESPACE_INPUT="Enter Docker Hub namespace/org [!DOCKER_USERNAME!]: "
if "!DOCKER_NAMESPACE_INPUT!"=="" set DOCKER_NAMESPACE=!DOCKER_USERNAME!
if not "!DOCKER_NAMESPACE_INPUT!"=="" set DOCKER_NAMESPACE=!DOCKER_NAMESPACE_INPUT!

set FULL_IMAGE_NAME=!DOCKER_NAMESPACE!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Logging in to Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub login failed.
    exit /b 1
)
echo Docker Hub login successful.
goto BUILD_IMAGE

:BUILD_IMAGE
echo.
echo ==============================================
echo   Building Docker image...
echo   Image: !FULL_IMAGE_NAME!
echo   Dockerfile: !DOCKERFILE_PATH!
echo   Context: !BUILD_CONTEXT!
echo ==============================================

docker build -f !DOCKERFILE_PATH! -t !FULL_IMAGE_NAME! !BUILD_CONTEXT!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo Docker build successful.

docker tag !FULL_IMAGE_NAME! !IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Pushing image to registry...
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   SUCCESS!
echo   Image pushed: !FULL_IMAGE_NAME!
echo ==============================================
echo.
echo To deploy to ECS, run: scripts\deploy-image.bat
echo Use image URI: !FULL_IMAGE_NAME!

endlocal

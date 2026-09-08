@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: build-push.bat - Build and push Docker image for cargo-tracker
:: ============================================================

set PROJECT_NAME=cargo-tracker
set DOCKERFILE_PATH=Dockerfile

echo ==============================================
echo   cargo-tracker - Docker Build ^& Push Script
echo ==============================================
echo.

:: Sanitize image name using PowerShell
for /f "delims=" %%i in ('powershell -Command "\"cargo-tracker\" -replace \"[^a-z0-9]\",\"-\" -replace \"^-+\",\"\" -replace \"-+$\",\"\""') do set IMAGE_NAME=%%i

:: Prompt for image tag
set /p IMAGE_TAG="Enter image tag [latest]: "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

echo.
echo Select container registry:
echo   1. AWS ECR
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice [1 or 2]: "

if "!REGISTRY_CHOICE!"=="1" goto ECR_SETUP
if "!REGISTRY_CHOICE!"=="2" goto DOCKERHUB_SETUP
echo ERROR: Invalid choice. Please enter 1 or 2.
exit /b 1

:ECR_SETUP
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
set /p AWS_ACCOUNT_ID="Enter AWS Account ID: "

if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)
if "!AWS_ACCOUNT_ID!"=="" (
    echo ERROR: AWS Account ID is required.
    exit /b 1
)

set REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com
set ECR_REPO=!IMAGE_NAME!
set FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!

echo.
echo Logging in to AWS ECR...
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ERROR: ECR login failed.
    exit /b 1
)

echo Checking if ECR repository exists...
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECR repository.
        exit /b 1
    )
)
echo ECR repository ready: !ECR_REPO!
goto BUILD

:DOCKERHUB_SETUP
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

set REGISTRY_URL=docker.io
set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Logging in to Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub login failed.
    exit /b 1
)
goto BUILD

:BUILD
echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Using Dockerfile: %DOCKERFILE_PATH%
echo Build context: . (project root)
echo.

docker build -f %DOCKERFILE_PATH% -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)

echo.
echo Pushing image: !FULL_IMAGE_NAME!
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   Build and push completed successfully!
echo   Image: !FULL_IMAGE_NAME!
echo ==============================================

endlocal

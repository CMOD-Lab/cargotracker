@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM build-push.bat - Build and push Docker image for cargo-tracker
REM ============================================================

set PROJECT_NAME=cargo-tracker
set DOCKERFILE_PATH=Dockerfile

echo ==============================================
echo   cargo-tracker - Docker Build ^& Push Script
echo ==============================================
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
echo   1. Azure Container Registry (ACR)
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice [1 or 2]: "

if "!REGISTRY_CHOICE!"=="1" goto ACR_SETUP
if "!REGISTRY_CHOICE!"=="2" goto DOCKERHUB_SETUP
echo ERROR: Invalid choice. Please enter 1 or 2.
exit /b 1

:ACR_SETUP
set /p ACR_NAME="Enter ACR name (e.g., myregistry): "
if "!ACR_NAME!"=="" (
    echo ERROR: ACR name cannot be empty.
    exit /b 1
)
set REGISTRY=!ACR_NAME!.azurecr.io
set FULL_IMAGE_NAME=!REGISTRY!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Logging in to Azure Container Registry: !ACR_NAME!...
az acr login --name !ACR_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: ACR login failed.
    exit /b 1
)
goto BUILD_IMAGE

:DOCKERHUB_SETUP
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
set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!

echo.
echo Logging in to Docker Hub...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub login failed.
    exit /b 1
)
goto BUILD_IMAGE

:BUILD_IMAGE
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
echo   SUCCESS: Image pushed successfully!
echo   Image: !FULL_IMAGE_NAME!
echo ==============================================
echo.
echo Use this image URI in your deployment:
echo   !FULL_IMAGE_NAME!

endlocal

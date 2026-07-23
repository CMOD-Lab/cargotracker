@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM build-push.bat - Build and Push Docker Image
REM Eclipse Cargo Tracker - Jakarta EE Application
REM ============================================================

set "PROJECT_NAME=cargo-tracker"
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."

echo ============================================================
echo   Eclipse Cargo Tracker - Docker Build ^& Push
echo ============================================================
echo.

REM Sanitize image name to lowercase using PowerShell
for /f "delims=" %%i in ('powershell -Command "\"cargo-tracker\".ToLower() -replace '[^a-z0-9]','-' -replace '^-+','' -replace '-+$',''"') do set "IMAGE_NAME=%%i"

REM Prompt for image tag
set /p "IMAGE_TAG_INPUT=Enter image tag [latest]: "
if "!IMAGE_TAG_INPUT!"=="" set "IMAGE_TAG_INPUT=latest"
for /f "delims=" %%i in ('powershell -Command "\"!IMAGE_TAG_INPUT!\".ToLower() -replace '[^a-z0-9._-]','-' -replace '^-+','' -replace '-+$',''"') do set "IMAGE_TAG=%%i"
if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"

echo.
echo Select container registry:
echo   1. Azure Container Registry (ACR)
echo   2. Docker Hub
echo.
set /p "REGISTRY_CHOICE=Enter choice [1 or 2]: "

if "!REGISTRY_CHOICE!"=="1" goto :acr_login
if "!REGISTRY_CHOICE!"=="2" goto :dockerhub_login
echo ERROR: Invalid choice. Please enter 1 or 2.
exit /b 1

:acr_login
echo.
set /p "ACR_NAME=Enter ACR name (e.g., myregistry): "
if "!ACR_NAME!"=="" (
    echo ERROR: ACR name cannot be empty.
    exit /b 1
)
for /f "delims=" %%i in ('powershell -Command "\"!ACR_NAME!\".ToLower()"') do set "ACR_NAME_LOWER=%%i"
set "REGISTRY=!ACR_NAME_LOWER!.azurecr.io"
set "FULL_IMAGE_NAME=!REGISTRY!/!IMAGE_NAME!:!IMAGE_TAG!"

echo.
echo Logging in to Azure Container Registry: !REGISTRY! ...
az acr login --name !ACR_NAME_LOWER!
if !ERRORLEVEL! neq 0 (
    echo ERROR: ACR login failed. Ensure you are logged in with 'az login'.
    exit /b 1
)
goto :build_image

:dockerhub_login
echo.
set /p "DOCKER_USERNAME=Enter Docker Hub username: "
if "!DOCKER_USERNAME!"=="" (
    echo ERROR: Docker Hub username cannot be empty.
    exit /b 1
)
set /p "DOCKER_PASSWORD=Enter Docker Hub password or access token: "
if "!DOCKER_PASSWORD!"=="" (
    echo ERROR: Docker Hub password cannot be empty.
    exit /b 1
)
set "REGISTRY=docker.io"
set "FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!"

echo.
echo Logging in to Docker Hub ...
echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker Hub login failed.
    exit /b 1
)
goto :build_image

:build_image
echo.
echo ------------------------------------------------------------
echo   Image Name   : !FULL_IMAGE_NAME!
echo   Build Context: !PROJECT_ROOT!
echo ------------------------------------------------------------
echo.

echo Building Docker image ...
docker build -f "!PROJECT_ROOT!\Dockerfile" -t "!FULL_IMAGE_NAME!" "!PROJECT_ROOT!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo Docker image built successfully: !FULL_IMAGE_NAME!

echo.
echo Pushing Docker image to registry ...
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

endlocal
exit /b 0

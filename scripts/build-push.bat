@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM build-push.bat  -  Build and push the cargo-tracker Docker image (Windows)
REM Supports: Azure Container Registry (ACR) and Docker Hub
REM Usage   : scripts\build-push.bat
REM =============================================================================

set "PROJECT_NAME=cargo-tracker"
set "DOCKERFILE_PATH=Dockerfile"
set "IMAGE_NAME=cargo-tracker"

echo ==============================================
echo   Eclipse Cargo Tracker - Docker Build ^& Push
echo ==============================================
echo.
echo Project : %PROJECT_NAME%
echo Image   : %IMAGE_NAME%
echo.

REM ---------------------------------------------------------------------------
REM Prompt for image tag
REM ---------------------------------------------------------------------------
set /p IMAGE_TAG="Enter image tag [latest]: "
if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"
echo Tag     : !IMAGE_TAG!
echo.

REM ---------------------------------------------------------------------------
REM Registry selection
REM ---------------------------------------------------------------------------
echo Select container registry:
echo   1) Azure Container Registry (ACR)
echo   2) Docker Hub
set /p REGISTRY_CHOICE="Enter choice [1]: "
if "!REGISTRY_CHOICE!"=="" set "REGISTRY_CHOICE=1"

if "!REGISTRY_CHOICE!"=="1" (
    REM ---- Azure ACR ----
    echo.
    echo --- Azure Container Registry ---
    set /p ACR_NAME="Enter ACR name (e.g. myregistry): "
    if "!ACR_NAME!"=="" (
        echo ERROR: ACR name cannot be empty.
        exit /b 1
    )

    set "REGISTRY=!ACR_NAME!.azurecr.io"
    set "FULL_IMAGE_NAME=!REGISTRY!/!IMAGE_NAME!:!IMAGE_TAG!"

    echo.
    echo Logging in to ACR: !ACR_NAME! ...
    az acr login --name !ACR_NAME!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: ACR login failed.
        exit /b 1
    )

) else if "!REGISTRY_CHOICE!"=="2" (
    REM ---- Docker Hub ----
    echo.
    echo --- Docker Hub ---
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

    set "FULL_IMAGE_NAME=!DOCKER_USERNAME!/!IMAGE_NAME!:!IMAGE_TAG!"

    echo.
    echo Logging in to Docker Hub ...
    echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Docker Hub login failed.
        exit /b 1
    )

) else (
    echo ERROR: Invalid registry choice '!REGISTRY_CHOICE!'.
    exit /b 1
)

echo.
echo Full image name: !FULL_IMAGE_NAME!
echo.

REM ---------------------------------------------------------------------------
REM Build Docker image
REM ---------------------------------------------------------------------------
echo Building Docker image ...
docker build -f "%DOCKERFILE_PATH%" -t "!FULL_IMAGE_NAME!" .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo Build successful.
echo.

REM ---------------------------------------------------------------------------
REM Push Docker image
REM ---------------------------------------------------------------------------
echo Pushing image to registry ...
docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   Image pushed successfully!
echo   !FULL_IMAGE_NAME!
echo ==============================================

endlocal

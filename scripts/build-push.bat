@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem Build and Push Docker Image - cargo-tracker
rem ============================================================

set PROJECT_NAME=cargo-tracker
set IMAGE_NAME=cargo-tracker

echo ============================================================
echo   Docker Build ^& Push - %PROJECT_NAME%
echo ============================================================
echo.

rem Prompt for image tag
set /p IMAGE_TAG_INPUT="Enter image tag (press Enter for 'latest'): "
if "!IMAGE_TAG_INPUT!"=="" (
    set IMAGE_TAG=latest
) else (
    set IMAGE_TAG=!IMAGE_TAG_INPUT!
)
echo Using image tag: !IMAGE_TAG!
echo.

rem Prompt for registry type
echo Select container registry:
echo   1. Azure Container Registry (ACR)
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter choice (1 or 2): "

if "!REGISTRY_CHOICE!"=="1" (
    rem Azure ACR
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

) else if "!REGISTRY_CHOICE!"=="2" (
    rem Docker Hub
    set /p DOCKER_USERNAME="Enter Docker Hub username: "
    set /p DOCKER_PASSWORD="Enter Docker Hub password/token: "
    set /p DOCKER_ORG="Enter Docker Hub repository (e.g., myorg): "
    if "!DOCKER_USERNAME!"=="" (
        echo ERROR: Docker Hub username cannot be empty.
        exit /b 1
    )
    if "!DOCKER_ORG!"=="" (
        echo ERROR: Docker Hub repository cannot be empty.
        exit /b 1
    )
    set FULL_IMAGE_NAME=!DOCKER_ORG!/!IMAGE_NAME!:!IMAGE_TAG!

    echo.
    echo Logging in to Docker Hub...
    echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Docker Hub login failed.
        exit /b 1
    )

) else (
    echo ERROR: Invalid choice. Please enter 1 or 2.
    exit /b 1
)

echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Build context: . (repository root)
echo ------------------------------------------------------------
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo Docker build successful.
echo.

echo Pushing image: !FULL_IMAGE_NAME!
echo ------------------------------------------------------------
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

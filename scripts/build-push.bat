@echo off
setlocal enabledelayedexpansion

set "PROJECT_NAME=cargo-tracker"
set "DOCKERFILE_PATH=Dockerfile"

echo ==============================================
echo   Cargo Tracker - Docker Build ^& Push Script
echo ==============================================
echo.

rem Prompt for image tag
set /p "IMAGE_TAG_INPUT=Enter image tag [latest]: "
if "!IMAGE_TAG_INPUT!"=="" set "IMAGE_TAG_INPUT=latest"

rem Sanitize tag using PowerShell
for /f "delims=" %%i in ('powershell -NoProfile -Command "$t = '!IMAGE_TAG_INPUT!'.ToLower() -replace '[^a-z0-9]+','-'; $t = $t.Trim('-'); if ($t -eq '') { $t = 'latest' }; Write-Output $t"') do set "IMAGE_TAG=%%i"

rem Sanitize project name
for /f "delims=" %%i in ('powershell -NoProfile -Command "$n = '!PROJECT_NAME!'.ToLower() -replace '[^a-z0-9]+','-'; $n = $n.Trim('-'); Write-Output $n"') do set "IMAGE_NAME=%%i"

echo.
echo Select container registry:
echo   1. Azure Container Registry (ACR)
echo   2. Docker Hub
set /p "REGISTRY_CHOICE=Enter choice [1]: "
if "!REGISTRY_CHOICE!"=="" set "REGISTRY_CHOICE=1"

if "!REGISTRY_CHOICE!"=="1" (
    rem Azure ACR
    set /p "ACR_NAME=Enter ACR name (e.g., myregistry): "
    if "!ACR_NAME!"=="" (
        echo ERROR: ACR name cannot be empty.
        exit /b 1
    )
    set "REGISTRY=!ACR_NAME!.azurecr.io"
    set "FULL_IMAGE_NAME=!REGISTRY!/!IMAGE_NAME!:!IMAGE_TAG!"

    echo.
    echo Logging in to Azure Container Registry: !ACR_NAME! ...
    az acr login --name !ACR_NAME!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: ACR login failed.
        exit /b 1
    )
    echo ACR login successful.

) else if "!REGISTRY_CHOICE!"=="2" (
    rem Docker Hub
    set /p "DOCKER_USERNAME=Enter Docker Hub username: "
    if "!DOCKER_USERNAME!"=="" (
        echo ERROR: Docker Hub username cannot be empty.
        exit /b 1
    )
    set /p "DOCKER_PASSWORD=Enter Docker Hub password/token: "
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
    echo Docker Hub login successful.

) else (
    echo ERROR: Invalid choice. Please enter 1 or 2.
    exit /b 1
)

echo.
echo Building Docker image: !FULL_IMAGE_NAME!
echo Build context: . (repository root)
echo Dockerfile: !DOCKERFILE_PATH!
echo.

docker build -f "!DOCKERFILE_PATH!" -t "!FULL_IMAGE_NAME!" .
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed.
    exit /b 1
)
echo.
echo Build successful.

echo Pushing image: !FULL_IMAGE_NAME! ...
docker push "!FULL_IMAGE_NAME!"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed.
    exit /b 1
)

echo.
echo ==============================================
echo   Image pushed successfully!
echo   Image: !FULL_IMAGE_NAME!
echo ==============================================

endlocal

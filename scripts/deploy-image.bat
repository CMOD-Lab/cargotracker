@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: deploy-image.bat - Deploy cargo-tracker to AWS EKS (Windows)
:: =============================================================================

set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"
set "MANIFESTS_DIR=kubernetes"

echo ==============================================
echo   cargo-tracker - Deploy to AWS EKS
echo ==============================================
echo.

:: -----------------------------------------------------------------------
:: Collect deployment inputs
:: -----------------------------------------------------------------------
set /p "AWS_REGION=Enter AWS Region (e.g. us-east-1): "
if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)

set /p "CLUSTER_NAME=Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: EKS Cluster Name is required.
    exit /b 1
)

set /p "IMAGE_URI=Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo --- Application Environment Variables ---
echo Press Enter to skip any variable.
echo.

set /p "POSTGRESQL_JDBC_URL=Enter POSTGRESQL_JDBC_URL (e.g. jdbc:postgresql://host:5432/cargotracker): "
set /p "POSTGRESQL_USERNAME=Enter POSTGRESQL_USERNAME [postgres]: "
if "!POSTGRESQL_USERNAME!"=="" set "POSTGRESQL_USERNAME=postgres"
set /p "POSTGRESQL_PASSWORD=Enter POSTGRESQL_PASSWORD: "
set /p "REDIS_HOST=Enter REDIS_HOST (ElastiCache endpoint): "
set /p "REDIS_PORT=Enter REDIS_PORT [6379]: "
if "!REDIS_PORT!"=="" set "REDIS_PORT=6379"
set /p "REDIS_PASSWORD=Enter REDIS_PASSWORD (leave blank if none): "

:: -----------------------------------------------------------------------
:: Configure kubectl for EKS
:: -----------------------------------------------------------------------
echo.
echo Configuring kubectl for EKS cluster: !CLUSTER_NAME! in !AWS_REGION! ...
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl.
    exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to EKS cluster.
    exit /b 1
)

:: -----------------------------------------------------------------------
:: Update Kubernetes manifests with actual values
:: -----------------------------------------------------------------------
echo.
echo Updating Kubernetes manifests with deployment values...

copy /Y "!MANIFESTS_DIR!\deployment.yaml" "!MANIFESTS_DIR!\deployment.yaml.deploy" >nul

powershell -NoProfile -Command ^
    "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"

if "!POSTGRESQL_JDBC_URL!" neq "" (
    powershell -NoProfile -Command ^
        "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{POSTGRESQL_JDBC_URL}}', '!POSTGRESQL_JDBC_URL!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"
)
if "!POSTGRESQL_USERNAME!" neq "" (
    powershell -NoProfile -Command ^
        "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{POSTGRESQL_USERNAME}}', '!POSTGRESQL_USERNAME!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"
)
if "!POSTGRESQL_PASSWORD!" neq "" (
    powershell -NoProfile -Command ^
        "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{POSTGRESQL_PASSWORD}}', '!POSTGRESQL_PASSWORD!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"
)
if "!REDIS_HOST!" neq "" (
    powershell -NoProfile -Command ^
        "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{REDIS_HOST}}', '!REDIS_HOST!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"
)
powershell -NoProfile -Command ^
    "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{REDIS_PORT}}', '!REDIS_PORT!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"
powershell -NoProfile -Command ^
    "(Get-Content '!MANIFESTS_DIR!\deployment.yaml.deploy') -replace '{{REDIS_PASSWORD}}', '!REDIS_PASSWORD!' | Set-Content '!MANIFESTS_DIR!\deployment.yaml.deploy'"

:: -----------------------------------------------------------------------
:: Apply Kubernetes manifests in order
:: -----------------------------------------------------------------------
echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "!MANIFESTS_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    del /f "!MANIFESTS_DIR!\deployment.yaml.deploy" >nul 2>&1
    exit /b 1
)

echo   [2/4] Applying deployment...
kubectl apply -f "!MANIFESTS_DIR!\deployment.yaml.deploy"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    del /f "!MANIFESTS_DIR!\deployment.yaml.deploy" >nul 2>&1
    exit /b 1
)

echo   [3/4] Applying service...
kubectl apply -f "!MANIFESTS_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    del /f "!MANIFESTS_DIR!\deployment.yaml.deploy" >nul 2>&1
    exit /b 1
)

echo   [4/4] Applying ingress...
kubectl apply -f "!MANIFESTS_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    del /f "!MANIFESTS_DIR!\deployment.yaml.deploy" >nul 2>&1
    exit /b 1
)

del /f "!MANIFESTS_DIR!\deployment.yaml.deploy" >nul 2>&1

:: -----------------------------------------------------------------------
:: Wait for rollout
:: -----------------------------------------------------------------------
echo.
echo Waiting for deployment rollout: !APP_NAME! in namespace !NAMESPACE! ...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed or timed out.
    echo To rollback: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

:: -----------------------------------------------------------------------
:: Verify resources
:: -----------------------------------------------------------------------
echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo Deployment completed successfully!
echo.
echo --- Rollback Instructions ---
echo To rollback to the previous version:
echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo.
echo To check rollout history:
echo   kubectl rollout history deployment/!APP_NAME! -n !NAMESPACE!

endlocal

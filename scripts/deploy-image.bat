@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM deploy-image.bat  -  Deploy cargo-tracker to Azure AKS (Windows)
REM Prerequisites    : azure-cli, kubectl
REM Usage            : scripts\deploy-image.bat
REM =============================================================================

set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"
set "K8S_DIR=kubernetes"

echo ==============================================
echo   Eclipse Cargo Tracker - AKS Deployment
echo ==============================================
echo.

REM ---------------------------------------------------------------------------
REM Collect Azure / AKS details
REM ---------------------------------------------------------------------------
set /p RESOURCE_GROUP="Enter Azure Resource Group name: "
if "!RESOURCE_GROUP!"=="" (
    echo ERROR: Resource group cannot be empty.
    exit /b 1
)

set /p CLUSTER_NAME="Enter AKS Cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: AKS cluster name cannot be empty.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g. myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

REM ---------------------------------------------------------------------------
REM Collect optional application environment variables
REM ---------------------------------------------------------------------------
echo.
echo --- Application Configuration (press Enter to use defaults) ---

set /p DB_DRIVER_CLASS="Enter DB_DRIVER_CLASS [org.h2.jdbcx.JdbcDataSource]: "
if "!DB_DRIVER_CLASS!"=="" set "DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource"

set /p DB_JDBC_URL="Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: "
if "!DB_JDBC_URL!"=="" set "DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database"

set /p DB_USER="Enter DB_USER []: "
if "!DB_USER!"=="" set "DB_USER="

set /p DB_PASSWORD="Enter DB_PASSWORD []: "
if "!DB_PASSWORD!"=="" set "DB_PASSWORD="

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL!"=="" set "GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"

REM ---------------------------------------------------------------------------
REM Configure kubectl for AKS
REM ---------------------------------------------------------------------------
echo.
echo Configuring kubectl for AKS cluster '!CLUSTER_NAME!' ...
az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials.
    exit /b 1
)

echo Verifying cluster connectivity ...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

REM ---------------------------------------------------------------------------
REM Substitute placeholders using PowerShell (temp copies)
REM ---------------------------------------------------------------------------
echo.
echo Preparing Kubernetes manifests ...

set "TMP_DIR=%TEMP%\cargo-tracker-k8s"
if exist "!TMP_DIR!" rmdir /s /q "!TMP_DIR!"
mkdir "!TMP_DIR!"

copy "%K8S_DIR%\namespace.yaml"   "!TMP_DIR!\namespace.yaml"   >nul
copy "%K8S_DIR%\deployment.yaml"  "!TMP_DIR!\deployment.yaml"  >nul
copy "%K8S_DIR%\service.yaml"     "!TMP_DIR!\service.yaml"     >nul
copy "%K8S_DIR%\ingress.yaml"     "!TMP_DIR!\ingress.yaml"     >nul

REM Use PowerShell to replace placeholders
powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '\{\{IMAGE_URI\}\}', '!IMAGE_URI!' -replace '\{\{DB_DRIVER_CLASS\}\}', '!DB_DRIVER_CLASS!' -replace '\{\{DB_JDBC_URL\}\}', '!DB_JDBC_URL!' -replace '\{\{DB_USER\}\}', '!DB_USER!' -replace '\{\{DB_PASSWORD\}\}', '!DB_PASSWORD!' -replace '\{\{GRAPH_TRAVERSAL_URL\}\}', '!GRAPH_TRAVERSAL_URL!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to substitute placeholders in deployment.yaml.
    exit /b 1
)

REM ---------------------------------------------------------------------------
REM Apply manifests in order
REM ---------------------------------------------------------------------------
echo.
echo Applying Kubernetes manifests ...

echo   [1/4] Applying namespace ...
kubectl apply -f "!TMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    exit /b 1
)

echo   [2/4] Applying deployment ...
kubectl apply -f "!TMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    exit /b 1
)

echo   [3/4] Applying service ...
kubectl apply -f "!TMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    exit /b 1
)

echo   [4/4] Applying ingress ...
kubectl apply -f "!TMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    exit /b 1
)

REM Clean up temp files
rmdir /s /q "!TMP_DIR!"

REM ---------------------------------------------------------------------------
REM Wait for rollout
REM ---------------------------------------------------------------------------
echo.
echo Waiting for deployment rollout ...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo.
    echo WARNING: Rollout did not complete within timeout. Checking pod status ...
    kubectl get pods -n !NAMESPACE!
    echo.
    echo To rollback, run:
    echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

REM ---------------------------------------------------------------------------
REM Verify resources
REM ---------------------------------------------------------------------------
echo.
echo Verifying deployed resources ...
kubectl get pods,svc,ingress -n !NAMESPACE!

REM ---------------------------------------------------------------------------
REM Display access URL
REM ---------------------------------------------------------------------------
echo.
echo ==============================================
echo   Deployment Complete!
echo ==============================================
echo.
echo   Application URL : http://cargo-tracker.example.com/
echo   Health Check    : http://cargo-tracker.example.com/cargo-tracker/rest/health
echo.
echo   To check pods   : kubectl get pods -n !NAMESPACE!
echo   To view logs    : kubectl logs -l app=!APP_NAME! -n !NAMESPACE! --tail=100
echo   To rollback     : kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo ==============================================

endlocal

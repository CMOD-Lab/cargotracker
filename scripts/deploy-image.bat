@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: deploy-image.bat - Deploy cargo-tracker to GCP GKE
:: ============================================================

echo ==============================================
echo   cargo-tracker - GKE Deployment Script
echo ==============================================
echo.

:: ---- Prompt for GCP / GKE details ----
set /p GCP_PROJECT="Enter GCP Project ID: "
if "!GCP_PROJECT!"=="" (
    echo ERROR: GCP Project ID is required.
    exit /b 1
)

set /p GCP_ZONE="Enter GCP Zone (e.g., us-central1-a): "
if "!GCP_ZONE!"=="" (
    echo ERROR: GCP Zone is required.
    exit /b 1
)

set /p CLUSTER_NAME="Enter GKE Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: GKE Cluster Name is required.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/repo/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo ---- Optional: Application Environment Variables ----
echo Press Enter to skip any variable.
echo.

set /p DB_JDBC_URL="Enter DB_JDBC_URL (or press Enter for default H2): "
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:h2:file:/opt/cargo-tracker-data/cargo-tracker-database

set /p DB_USER="Enter DB_USER (or press Enter to skip): "
set /p DB_PASSWORD="Enter DB_PASSWORD (or press Enter to skip): "

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL (or press Enter for default): "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path

echo.
echo ----------------------------------------------
echo   GCP Project : !GCP_PROJECT!
echo   GCP Zone    : !GCP_ZONE!
echo   GKE Cluster : !CLUSTER_NAME!
echo   Image URI   : !IMAGE_URI!
echo ----------------------------------------------
echo.

:: ---- Configure kubectl for GKE ----
echo Configuring kubectl for GKE cluster...
gcloud container clusters get-credentials !CLUSTER_NAME! --zone !GCP_ZONE! --project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for GKE cluster.
    exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to GKE cluster.
    exit /b 1
)

echo.
echo Updating Kubernetes manifests with deployment values...

:: Copy manifests to temp location
set DEPLOY_DIR=%TEMP%\cargo-tracker-deploy
if exist "!DEPLOY_DIR!" rmdir /s /q "!DEPLOY_DIR!"
mkdir "!DEPLOY_DIR!"

copy kubernetes\namespace.yaml "!DEPLOY_DIR!\namespace.yaml" >nul
copy kubernetes\deployment.yaml "!DEPLOY_DIR!\deployment.yaml" >nul
copy kubernetes\service.yaml "!DEPLOY_DIR!\service.yaml" >nul
copy kubernetes\ingress.yaml "!DEPLOY_DIR!\ingress.yaml" >nul

:: Replace placeholders using PowerShell
powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '\{\{IMAGE_URI\}\}', '!IMAGE_URI!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '\{\{DB_JDBC_URL\}\}', '!DB_JDBC_URL!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '\{\{DB_USER\}\}', '!DB_USER!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '\{\{DB_PASSWORD\}\}', '!DB_PASSWORD!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '\{\{GRAPH_TRAVERSAL_URL\}\}', '!GRAPH_TRAVERSAL_URL!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"

echo.
echo Applying Kubernetes manifests...
echo ----------------------------------------------

echo [1/4] Applying namespace...
kubectl apply -f "!DEPLOY_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply namespace. & exit /b 1)

echo [2/4] Applying deployment...
kubectl apply -f "!DEPLOY_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply deployment. & exit /b 1)

echo [3/4] Applying service...
kubectl apply -f "!DEPLOY_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply service. & exit /b 1)

echo [4/4] Applying ingress...
kubectl apply -f "!DEPLOY_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply ingress. & exit /b 1)

echo.
echo Waiting for deployment rollout...
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed or timed out.
    echo Run: kubectl describe deployment/cargo-tracker -n cargo-tracker
    exit /b 1
)

echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n cargo-tracker

echo.
echo ==============================================
echo   Deployment complete!
echo   Namespace : cargo-tracker
echo   Image     : !IMAGE_URI!
echo ==============================================
echo.
echo Rollback command (if needed):
echo   kubectl rollout undo deployment/cargo-tracker -n cargo-tracker

:: Cleanup
rmdir /s /q "!DEPLOY_DIR!" 2>nul

endlocal

@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy cargo-tracker to GCP GKE
REM Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
REM ============================================================

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set K8S_DIR=%PROJECT_ROOT%\kubernetes

echo ============================================================
echo   Eclipse Cargo Tracker - GKE Deployment
echo ============================================================
echo.

REM ---- Prompt for GCP configuration ----
set /p GCP_PROJECT="Enter GCP Project ID: "
if "!GCP_PROJECT!"=="" (
    echo ERROR: GCP Project ID is required.
    exit /b 1
)

set /p GCP_ZONE="Enter GCP Zone (e.g. us-central1-a): "
if "!GCP_ZONE!"=="" (
    echo ERROR: GCP Zone is required.
    exit /b 1
)

set /p CLUSTER_NAME="Enter GKE Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: GKE Cluster Name is required.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI: "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo --- Optional Application Configuration ---
echo (Press Enter to skip any value and use the default)
echo.

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/rest/graph-traversal/shortest-path

set /p DB_JDBC_URL="Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: "
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database

set /p DB_USER="Enter DB_USER []: "
set /p DB_PASSWORD="Enter DB_PASSWORD []: "

echo.
echo ============================================================
echo   Deployment Summary
echo   GCP Project : !GCP_PROJECT!
echo   GCP Zone    : !GCP_ZONE!
echo   Cluster     : !CLUSTER_NAME!
echo   Image       : !IMAGE_URI!
echo   Namespace   : !NAMESPACE!
echo ============================================================
echo.

REM ---- Configure kubectl for GKE ----
echo Configuring kubectl for GKE cluster...
gcloud container clusters get-credentials !CLUSTER_NAME! --zone !GCP_ZONE! --project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for GKE cluster.
    exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to cluster.
    exit /b 1
)

REM ---- Create temp directory for modified manifests ----
set TMP_DIR=%TEMP%\cargo-tracker-deploy-%RANDOM%
mkdir "!TMP_DIR!"

copy "!K8S_DIR!\namespace.yaml" "!TMP_DIR!\namespace.yaml" >nul
copy "!K8S_DIR!\deployment.yaml" "!TMP_DIR!\deployment.yaml" >nul
copy "!K8S_DIR!\service.yaml" "!TMP_DIR!\service.yaml" >nul
copy "!K8S_DIR!\ingress.yaml" "!TMP_DIR!\ingress.yaml" >nul

REM ---- Update manifests using PowerShell ----
echo.
echo Updating Kubernetes manifests with deployment values...

powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to update IMAGE_URI & exit /b 1)

powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to update GRAPH_TRAVERSAL_URL & exit /b 1)

powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to update DB_JDBC_URL & exit /b 1)

powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '{{DB_USER}}', '!DB_USER!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to update DB_USER & exit /b 1)

powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '{{DB_PASSWORD}}', '!DB_PASSWORD!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to update DB_PASSWORD & exit /b 1)

REM ---- Apply manifests in order ----
echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "!TMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply namespace & exit /b 1)

echo   [2/4] Applying deployment...
kubectl apply -f "!TMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply deployment & exit /b 1)

echo   [3/4] Applying service...
kubectl apply -f "!TMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply service & exit /b 1)

echo   [4/4] Applying ingress...
kubectl apply -f "!TMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply ingress & exit /b 1)

REM ---- Wait for rollout ----
echo.
echo Waiting for deployment rollout...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed. Initiating rollback...
    kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    echo Rollback initiated. Check pod status:
    kubectl get pods -n !NAMESPACE!
    rmdir /s /q "!TMP_DIR!"
    exit /b 1
)

REM ---- Verify resources ----
echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ============================================================
echo   DEPLOYMENT SUCCESSFUL!
echo   Application : !APP_NAME!
echo   Namespace   : !NAMESPACE!
echo   Image       : !IMAGE_URI!
echo ============================================================
echo.
echo Useful commands:
echo   kubectl get pods -n !NAMESPACE!
echo   kubectl logs -f deployment/!APP_NAME! -n !NAMESPACE!
echo   kubectl describe deployment/!APP_NAME! -n !NAMESPACE!
echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!

REM Cleanup
rmdir /s /q "!TMP_DIR!"

endlocal

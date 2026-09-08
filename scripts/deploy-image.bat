@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy to GCP GKE (Windows)
REM Eclipse Cargo Tracker - Jakarta EE 10 Application
REM Target Platform: GCP GKE
REM ============================================================

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker
set K8S_DIR=kubernetes
set TEMP_DIR=%TEMP%\cargo-tracker-k8s-deploy

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

set /p IMAGE_URI="Enter full Docker Image URI (e.g., us-central1-docker.pkg.dev/my-project/repo/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker Image URI is required.
    exit /b 1
)

echo.
echo ---- Optional: Application Environment Variables ----
echo Press Enter to skip any variable.
echo.

set /p DB_JDBC_URL_VAL="Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/db) [skip]: "
set /p DB_USER_VAL="Enter DB_USER [skip]: "
set /p DB_PASSWORD_VAL="Enter DB_PASSWORD [skip]: "
set /p GRAPH_TRAVERSAL_URL_VAL="Enter GRAPH_TRAVERSAL_URL [skip]: "

echo.
echo ------------------------------------------------------------
echo   GCP Project  : !GCP_PROJECT!
echo   GCP Zone     : !GCP_ZONE!
echo   Cluster      : !CLUSTER_NAME!
echo   Image URI    : !IMAGE_URI!
echo   Namespace    : !NAMESPACE!
echo ------------------------------------------------------------
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

echo.
echo Updating Kubernetes manifests with deployment values...

REM Copy manifests to temp directory
if exist "!TEMP_DIR!" rmdir /s /q "!TEMP_DIR!"
xcopy /s /e /i /q "!K8S_DIR!" "!TEMP_DIR!" > nul

REM Replace IMAGE_URI placeholder using PowerShell
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to update IMAGE_URI in deployment.yaml.
    exit /b 1
)

REM Replace DB_JDBC_URL
if "!DB_JDBC_URL_VAL!"=="" set DB_JDBC_URL_VAL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL_VAL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"

REM Replace DB_USER
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_USER}}', '!DB_USER_VAL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"

REM Replace DB_PASSWORD
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_PASSWORD}}', '!DB_PASSWORD_VAL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"

REM Replace GRAPH_TRAVERSAL_URL
if "!GRAPH_TRAVERSAL_URL_VAL!"=="" set GRAPH_TRAVERSAL_URL_VAL=http://localhost:8080/rest/graph-traversal/shortest-path
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL_VAL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"

echo Manifests updated.
echo.

REM ---- Apply Kubernetes manifests in order ----
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "!TEMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.yaml
    exit /b 1
)

echo   [2/4] Applying deployment...
kubectl apply -f "!TEMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.yaml
    exit /b 1
)

echo   [3/4] Applying service...
kubectl apply -f "!TEMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.yaml
    exit /b 1
)

echo   [4/4] Applying ingress...
kubectl apply -f "!TEMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.yaml
    exit /b 1
)

echo.
echo Waiting for deployment rollout to complete...
echo (Note: Payara Micro may take 2-3 minutes to start)
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo WARNING: Rollout did not complete within timeout. Check pod status manually.
)

echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ------------------------------------------------------------
echo   Deployment Complete!
echo.
echo   Application URL: http://cargo-tracker.example.com
echo   (Update ingress.yaml with your actual domain)
echo.
echo   To check pod logs:
echo     kubectl logs -l app=!APP_NAME! -n !NAMESPACE! --tail=100
echo.
echo   To rollback if needed:
echo     kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo ------------------------------------------------------------

REM Cleanup temp files
if exist "!TEMP_DIR!" rmdir /s /q "!TEMP_DIR!"

endlocal

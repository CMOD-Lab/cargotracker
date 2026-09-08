@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM deploy-image.bat - Deploy Eclipse Cargo Tracker to GCP GKE (Windows)
REM Target Platform: GCP GKE (Google Kubernetes Engine)
REM =============================================================================

set NAMESPACE=cargo-tracker
set APP_NAME=cargo-tracker

echo ==============================================
echo  Eclipse Cargo Tracker - GKE Deploy Script
echo ==============================================
echo.

REM -------------------------------------------------------
REM Prompt for GCP configuration
REM -------------------------------------------------------
set /p GCP_PROJECT="Enter GCP Project ID: "
if "!GCP_PROJECT!"=="" (
    echo ERROR: GCP Project ID cannot be empty.
    exit /b 1
)

set /p GCP_ZONE="Enter GCP Zone (e.g., us-central1-a): "
if "!GCP_ZONE!"=="" (
    echo ERROR: GCP Zone cannot be empty.
    exit /b 1
)

set /p CLUSTER_NAME="Enter GKE Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: GKE Cluster Name cannot be empty.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/my-repo/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI cannot be empty.
    exit /b 1
)

REM -------------------------------------------------------
REM Prompt for application environment variables
REM -------------------------------------------------------
echo.
echo --- Application Environment Variables ---
echo (Press Enter to use default values)
echo.

set /p DB_HOST="Enter DB_HOST (PostgreSQL host) [default: localhost]: "
if "!DB_HOST!"=="" set DB_HOST=localhost

set /p DB_PORT="Enter DB_PORT [default: 5432]: "
if "!DB_PORT!"=="" set DB_PORT=5432

set /p DB_NAME="Enter DB_NAME [default: postgres]: "
if "!DB_NAME!"=="" set DB_NAME=postgres

set /p DB_USER="Enter DB_USER [default: postgres]: "
if "!DB_USER!"=="" set DB_USER=postgres

set /p DB_PASSWORD="Enter DB_PASSWORD [default: postgres]: "
if "!DB_PASSWORD!"=="" set DB_PASSWORD=postgres

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL [default: http://localhost:8080/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/rest/graph-traversal/shortest-path

REM -------------------------------------------------------
REM Configure kubectl for GKE
REM -------------------------------------------------------
echo.
echo Configuring kubectl for GKE cluster: !CLUSTER_NAME!...
gcloud container clusters get-credentials !CLUSTER_NAME! --zone !GCP_ZONE! --project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get GKE cluster credentials.
    exit /b 1
)

echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to Kubernetes cluster.
    exit /b 1
)

REM -------------------------------------------------------
REM Copy manifests to temp directory and update placeholders
REM -------------------------------------------------------
echo.
echo Updating Kubernetes manifests with deployment values...

set TEMP_DIR=%TEMP%\cargo-tracker-k8s
if exist "!TEMP_DIR!" rmdir /s /q "!TEMP_DIR!"
mkdir "!TEMP_DIR!"

REM Copy kubernetes manifests to temp dir
copy /y "kubernetes\namespace.yaml"  "!TEMP_DIR!\namespace.yaml"  >nul
copy /y "kubernetes\deployment.yaml" "!TEMP_DIR!\deployment.yaml" >nul
copy /y "kubernetes\service.yaml"    "!TEMP_DIR!\service.yaml"    >nul
copy /y "kubernetes\ingress.yaml"    "!TEMP_DIR!\ingress.yaml"    >nul

REM Replace placeholders using PowerShell
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}','!IMAGE_URI!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to update IMAGE_URI & exit /b 1)

powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_HOST}}','!DB_HOST!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_PORT}}','!DB_PORT!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_NAME}}','!DB_NAME!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_USER}}','!DB_USER!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_PASSWORD}}','!DB_PASSWORD!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}','!GRAPH_TRAVERSAL_URL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"

REM -------------------------------------------------------
REM Apply Kubernetes manifests in order
REM -------------------------------------------------------
echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "!TEMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply namespace & exit /b 1)

echo   [2/4] Applying deployment...
kubectl apply -f "!TEMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply deployment & exit /b 1)

echo   [3/4] Applying service...
kubectl apply -f "!TEMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply service & exit /b 1)

echo   [4/4] Applying ingress...
kubectl apply -f "!TEMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (echo ERROR: Failed to apply ingress & exit /b 1)

REM -------------------------------------------------------
REM Wait for rollout
REM -------------------------------------------------------
echo.
echo Waiting for deployment rollout to complete...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo.
    echo ERROR: Deployment rollout failed or timed out.
    echo To rollback, run: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

REM -------------------------------------------------------
REM Verify deployment
REM -------------------------------------------------------
echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ==============================================
echo  SUCCESS: Deployment complete!
echo  Run the following to get the Ingress IP:
echo  kubectl get ingress -n !NAMESPACE!
echo ==============================================
echo.
echo Useful commands:
echo   View pods:  kubectl get pods -n !NAMESPACE!
echo   View logs:  kubectl logs -l app=!APP_NAME! -n !NAMESPACE! --tail=100
echo   Rollback:   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo   Scale:      kubectl scale deployment/!APP_NAME! --replicas=3 -n !NAMESPACE!

REM Cleanup temp files
rmdir /s /q "!TEMP_DIR!"

endlocal

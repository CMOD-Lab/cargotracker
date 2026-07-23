@echo off
setlocal enabledelayedexpansion

set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"
set "K8S_DIR=kubernetes"
set "TMP_DIR=%TEMP%\cargo-tracker-k8s-deploy"

echo ============================================================
echo   Cargo Tracker - Deploy to Azure AKS
echo ============================================================
echo.

rem ── Azure credentials ──────────────────────────────────────────
set /p "RESOURCE_GROUP=Enter Azure Resource Group name: "
if "!RESOURCE_GROUP!"=="" (
    echo ERROR: Resource group cannot be empty.
    exit /b 1
)

set /p "CLUSTER_NAME=Enter AKS Cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: AKS cluster name cannot be empty.
    exit /b 1
)

rem ── Docker image ───────────────────────────────────────────────
set /p "IMAGE_URI=Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

rem ── Application environment variables ─────────────────────────
echo.
echo Configure application environment variables (press Enter to use defaults):

set /p "DB_JDBC_URL_VAL=Enter DB_JDBC_URL [jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database]: "
if "!DB_JDBC_URL_VAL!"=="" set "DB_JDBC_URL_VAL=jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database"

set /p "DB_USER_VAL=Enter DB_USER [leave empty for H2]: "

set /p "DB_PASSWORD_VAL=Enter DB_PASSWORD [leave empty for H2]: "

set /p "GRAPH_TRAVERSAL_URL_VAL=Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL_VAL!"=="" set "GRAPH_TRAVERSAL_URL_VAL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"

rem ── Configure kubectl ──────────────────────────────────────────
echo.
echo Configuring kubectl for AKS cluster: !CLUSTER_NAME! ...
az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials.
    exit /b 1
)
echo kubectl configured successfully.

echo.
echo Verifying cluster connectivity ...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

rem ── Copy manifests to temp dir ─────────────────────────────────
echo.
echo Updating Kubernetes manifests with deployment values ...
if exist "!TMP_DIR!" rmdir /s /q "!TMP_DIR!"
xcopy /e /i /q "!K8S_DIR!" "!TMP_DIR!" >nul

rem Replace placeholders using PowerShell
powershell -NoProfile -Command ^
  "(Get-Content '!TMP_DIR!\deployment.yaml') ^
   -replace '{{IMAGE_URI}}','!IMAGE_URI!' ^
   -replace '{{DB_JDBC_URL}}','!DB_JDBC_URL_VAL!' ^
   -replace '{{DB_USER}}','!DB_USER_VAL!' ^
   -replace '{{DB_PASSWORD}}','!DB_PASSWORD_VAL!' ^
   -replace '{{GRAPH_TRAVERSAL_URL}}','!GRAPH_TRAVERSAL_URL_VAL!' ^
   | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to update deployment manifest.
    exit /b 1
)
echo Manifests updated.

rem ── Apply manifests ────────────────────────────────────────────
echo.
echo Applying Kubernetes manifests ...

echo   [1/4] Applying namespace ...
kubectl apply -f "!TMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply namespace. & exit /b 1 )

echo   [2/4] Applying deployment ...
kubectl apply -f "!TMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply deployment. & exit /b 1 )

echo   [3/4] Applying service ...
kubectl apply -f "!TMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply service. & exit /b 1 )

echo   [4/4] Applying ingress ...
kubectl apply -f "!TMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply ingress. & exit /b 1 )

rem ── Wait for rollout ───────────────────────────────────────────
echo.
echo Waiting for deployment rollout ...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed.
    echo Run: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

rem ── Verify resources ───────────────────────────────────────────
echo.
echo Verifying deployed resources ...
kubectl get pods,svc,ingress -n !NAMESPACE!

rem ── Display access info ────────────────────────────────────────
echo.
echo ============================================================
echo   Deployment Complete!
echo   Application: !APP_NAME!
echo   Namespace:   !NAMESPACE!
echo   Image:       !IMAGE_URI!
echo.
echo   Rollback command (if needed):
echo     kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo ============================================================

rem Cleanup
if exist "!TMP_DIR!" rmdir /s /q "!TMP_DIR!"

endlocal

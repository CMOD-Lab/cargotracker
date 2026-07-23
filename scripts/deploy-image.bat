@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy Eclipse Cargo Tracker to Azure AKS
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "K8S_DIR=%PROJECT_ROOT%\kubernetes"
set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"

echo ============================================================
echo   Eclipse Cargo Tracker - Deploy to Azure AKS
echo ============================================================
echo.

REM ---- Validate prerequisites ----
echo Checking prerequisites ...
where az >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo ERROR: Azure CLI (az) is not installed. Please install it first.
    exit /b 1
)
where kubectl >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo ERROR: kubectl is not installed. Please install it first.
    exit /b 1
)
echo Prerequisites OK.
echo.

REM ---- Prompt for Azure details ----
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

REM ---- Prompt for Docker image URI ----
echo.
set /p "IMAGE_URI=Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

REM ---- Prompt for application environment variables ----
echo.
echo ------------------------------------------------------------
echo   Application Configuration (press Enter to use defaults)
echo ------------------------------------------------------------

set /p "POSTGRES_HOST_INPUT=Enter POSTGRES_HOST [localhost]: "
if "!POSTGRES_HOST_INPUT!"=="" set "POSTGRES_HOST_INPUT=localhost"
set "POSTGRES_HOST=!POSTGRES_HOST_INPUT!"

set /p "POSTGRES_PORT_INPUT=Enter POSTGRES_PORT [5432]: "
if "!POSTGRES_PORT_INPUT!"=="" set "POSTGRES_PORT_INPUT=5432"
set "POSTGRES_PORT=!POSTGRES_PORT_INPUT!"

set /p "POSTGRES_DB_INPUT=Enter POSTGRES_DB [cargotracker]: "
if "!POSTGRES_DB_INPUT!"=="" set "POSTGRES_DB_INPUT=cargotracker"
set "POSTGRES_DB=!POSTGRES_DB_INPUT!"

set /p "POSTGRES_USER_INPUT=Enter POSTGRES_USER [postgres]: "
if "!POSTGRES_USER_INPUT!"=="" set "POSTGRES_USER_INPUT=postgres"
set "POSTGRES_USER=!POSTGRES_USER_INPUT!"

set /p "POSTGRES_PASSWORD_INPUT=Enter POSTGRES_PASSWORD [postgres]: "
if "!POSTGRES_PASSWORD_INPUT!"=="" set "POSTGRES_PASSWORD_INPUT=postgres"
set "POSTGRES_PASSWORD=!POSTGRES_PASSWORD_INPUT!"

REM ---- Configure kubectl for AKS ----
echo.
echo Configuring kubectl for AKS cluster: !CLUSTER_NAME! ...
az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials. Check resource group and cluster name.
    exit /b 1
)

REM ---- Verify cluster connectivity ----
echo.
echo Verifying cluster connectivity ...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)
echo.

REM ---- Create temp directory for modified manifests ----
set "TMP_DIR=%TEMP%\cargo-tracker-deploy-%RANDOM%"
mkdir "!TMP_DIR!"
copy "!K8S_DIR!\*.yaml" "!TMP_DIR!\" >nul

REM ---- Replace placeholders using PowerShell ----
echo Updating Kubernetes manifests with deployment values ...

powershell -Command "(Get-Content '!TMP_DIR!\deployment.yaml') -replace '\{\{IMAGE_URI\}\}','!IMAGE_URI!' -replace '\{\{POSTGRES_HOST\}\}','!POSTGRES_HOST!' -replace '\{\{POSTGRES_PORT\}\}','!POSTGRES_PORT!' -replace '\{\{POSTGRES_DB\}\}','!POSTGRES_DB!' -replace '\{\{POSTGRES_USER\}\}','!POSTGRES_USER!' -replace '\{\{POSTGRES_PASSWORD\}\}','!POSTGRES_PASSWORD!' | Set-Content '!TMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to update deployment manifest.
    exit /b 1
)
echo Manifests updated successfully.
echo.

REM ---- Apply Kubernetes manifests in order ----
echo Applying Kubernetes manifests ...

echo   [1/4] Applying namespace ...
kubectl apply -f "!TMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace manifest.
    exit /b 1
)

echo   [2/4] Applying deployment ...
kubectl apply -f "!TMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment manifest.
    exit /b 1
)

echo   [3/4] Applying service ...
kubectl apply -f "!TMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service manifest.
    exit /b 1
)

echo   [4/4] Applying ingress ...
kubectl apply -f "!TMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress manifest.
    exit /b 1
)

echo.
echo All manifests applied successfully.

REM ---- Wait for deployment rollout ----
echo.
echo Waiting for deployment rollout to complete ...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo.
    echo WARNING: Deployment rollout did not complete within timeout.
    echo To rollback, run: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

REM ---- Verify deployed resources ----
echo.
echo ------------------------------------------------------------
echo   Deployed Resources in namespace: !NAMESPACE!
echo ------------------------------------------------------------
kubectl get pods,svc,ingress -n !NAMESPACE!

REM ---- Display application URL ----
echo.
echo ------------------------------------------------------------
echo   Application Access Information
echo ------------------------------------------------------------
echo   Application URL : http://cargo-tracker.example.com/cargo-tracker
echo   Note: Update the host in kubernetes/ingress.yaml with your actual domain.
echo         Run: kubectl get ingress -n !NAMESPACE! to check ingress status.
echo.

REM ---- Cleanup temp files ----
rmdir /s /q "!TMP_DIR!" >nul 2>&1

echo ============================================================
echo   SUCCESS: Eclipse Cargo Tracker deployed to AKS!
echo ============================================================
echo.
echo Useful commands:
echo   View pods    : kubectl get pods -n !NAMESPACE!
echo   View logs    : kubectl logs -f deployment/!APP_NAME! -n !NAMESPACE!
echo   Rollback     : kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo   Scale        : kubectl scale deployment/!APP_NAME! --replicas=3 -n !NAMESPACE!

endlocal
exit /b 0

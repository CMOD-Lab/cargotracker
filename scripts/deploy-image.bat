@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem deploy-image.bat - Deploy Eclipse Cargo Tracker to Azure AKS
rem ============================================================

set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "K8S_DIR=%PROJECT_ROOT%\kubernetes"

echo ============================================================
echo   Eclipse Cargo Tracker - Deploy to Azure AKS
echo ============================================================
echo.

rem ---- Validate prerequisites ----
echo Checking prerequisites...
where az >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Azure CLI (az) is not installed.
    echo Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
    exit /b 1
)
where kubectl >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: kubectl is not installed.
    echo Install from: https://kubernetes.io/docs/tasks/tools/
    exit /b 1
)
echo   [OK] Azure CLI found
echo   [OK] kubectl found
echo.

rem ---- Prompt for inputs ----
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

set /p "IMAGE_URI=Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

echo.
echo ---- Optional Environment Configuration ----
echo Press Enter to skip any value and use defaults.
echo.

set /p "GRAPH_TRAVERSAL_URL_INPUT=Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL_INPUT!"=="" (
    set "GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"
) else (
    set "GRAPH_TRAVERSAL_URL=!GRAPH_TRAVERSAL_URL_INPUT!"
)

set /p "DB_DRIVER_CLASS_INPUT=Enter DB_DRIVER_CLASS [org.h2.jdbcx.JdbcDataSource]: "
if "!DB_DRIVER_CLASS_INPUT!"=="" (
    set "DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource"
) else (
    set "DB_DRIVER_CLASS=!DB_DRIVER_CLASS_INPUT!"
)

set /p "DB_JDBC_URL_INPUT=Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: "
if "!DB_JDBC_URL_INPUT!"=="" (
    set "DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database"
) else (
    set "DB_JDBC_URL=!DB_JDBC_URL_INPUT!"
)

echo.
echo ============================================================
echo   Deployment Configuration:
echo   Resource Group : !RESOURCE_GROUP!
echo   AKS Cluster    : !CLUSTER_NAME!
echo   Image URI      : !IMAGE_URI!
echo   Namespace      : !NAMESPACE!
echo ============================================================
echo.

rem ---- Configure kubectl for AKS ----
echo Configuring kubectl for AKS cluster: !CLUSTER_NAME! ...
az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to get AKS credentials. Check resource group and cluster name.
    exit /b 1
)
echo   [OK] kubectl configured
echo.

rem ---- Verify cluster connectivity ----
echo Verifying cluster connectivity...
kubectl cluster-info
if %ERRORLEVEL% neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)
echo   [OK] Cluster is reachable
echo.

rem ---- Create temp working directory ----
set "DEPLOY_DIR=%TEMP%\cargo-tracker-deploy-%RANDOM%"
mkdir "!DEPLOY_DIR!"
xcopy /E /I /Q "!K8S_DIR!" "!DEPLOY_DIR!" >nul

rem ---- Replace placeholders using PowerShell ----
echo Updating manifests with deployment values...

powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to update IMAGE_URI & exit /b 1 )

powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to update GRAPH_TRAVERSAL_URL & exit /b 1 )

powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '{{DB_DRIVER_CLASS}}', '!DB_DRIVER_CLASS!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to update DB_DRIVER_CLASS & exit /b 1 )

powershell -Command "(Get-Content '!DEPLOY_DIR!\deployment.yaml') -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL!' | Set-Content '!DEPLOY_DIR!\deployment.yaml'"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to update DB_JDBC_URL & exit /b 1 )

echo   [OK] Placeholders replaced
echo.

rem ---- Apply Kubernetes manifests ----
echo Applying Kubernetes manifests...

echo   Applying namespace...
kubectl apply -f "!DEPLOY_DIR!\namespace.yaml"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to apply namespace & exit /b 1 )

echo   Applying deployment...
kubectl apply -f "!DEPLOY_DIR!\deployment.yaml"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to apply deployment & exit /b 1 )

echo   Applying service...
kubectl apply -f "!DEPLOY_DIR!\service.yaml"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to apply service & exit /b 1 )

echo   Applying ingress...
kubectl apply -f "!DEPLOY_DIR!\ingress.yaml"
if %ERRORLEVEL% neq 0 ( echo ERROR: Failed to apply ingress & exit /b 1 )

echo   [OK] All manifests applied
echo.

rem ---- Wait for rollout ----
echo Waiting for deployment rollout (this may take several minutes for JVM startup)...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Deployment rollout failed or timed out.
    echo Run the following to investigate:
    echo   kubectl describe pods -n !NAMESPACE!
    echo   kubectl logs -l app=!APP_NAME! -n !NAMESPACE! --tail=50
    echo.
    echo To rollback:
    echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    rmdir /S /Q "!DEPLOY_DIR!"
    exit /b 1
)
echo   [OK] Deployment rollout complete
echo.

rem ---- Verify resources ----
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!
echo.

rem ---- Cleanup ----
rmdir /S /Q "!DEPLOY_DIR!"

echo ============================================================
echo   DEPLOYMENT SUCCESSFUL!
echo ============================================================
echo.
echo   Application URL : http://cargo-tracker.example.com/cargo-tracker
echo   Health Check    : http://cargo-tracker.example.com/cargo-tracker/rest/health
echo.
echo   Useful commands:
echo     kubectl get pods -n !NAMESPACE!
echo     kubectl logs -l app=!APP_NAME! -n !NAMESPACE! -f
echo     kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
echo.

endlocal

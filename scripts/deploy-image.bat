@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy cargo-tracker to Azure AKS
REM ============================================================

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker
set MANIFESTS_DIR=kubernetes

echo ==============================================
echo   cargo-tracker - Azure AKS Deployment Script
echo ==============================================
echo.

REM Prompt for Azure resource group
set /p RESOURCE_GROUP="Enter Azure Resource Group name: "
if "!RESOURCE_GROUP!"=="" (
    echo ERROR: Resource group cannot be empty.
    exit /b 1
)

REM Prompt for AKS cluster name
set /p CLUSTER_NAME="Enter AKS Cluster name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: AKS cluster name cannot be empty.
    exit /b 1
)

REM Prompt for Docker image URI
set /p IMAGE_URI="Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

echo.
echo --- Application Configuration ---
echo Provide values for environment variables (press Enter to use default):
echo.

set /p DB_JDBC_URL_VAL="Enter DB_JDBC_URL [jdbc:postgresql://postgres-service:5432/cargotracker]: "
if "!DB_JDBC_URL_VAL!"=="" set DB_JDBC_URL_VAL=jdbc:postgresql://postgres-service:5432/cargotracker

set /p DB_USER_VAL="Enter DB_USER [postgres]: "
if "!DB_USER_VAL!"=="" set DB_USER_VAL=postgres

set /p DB_PASSWORD_VAL="Enter DB_PASSWORD [changeme]: "
if "!DB_PASSWORD_VAL!"=="" set DB_PASSWORD_VAL=changeme

set /p GRAPH_TRAVERSAL_URL_VAL="Enter GRAPH_TRAVERSAL_URL [http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL_VAL!"=="" set GRAPH_TRAVERSAL_URL_VAL=http://cargo-tracker-service/cargo-tracker/rest/graph-traversal/shortest-path

echo.
echo --- Configuring kubectl for AKS ---
az aks get-credentials --resource-group !RESOURCE_GROUP! --name !CLUSTER_NAME! --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials.
    exit /b 1
)

echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

echo.
echo --- Updating Kubernetes manifests ---

REM Create temp directory for manifests
if exist "%TEMP%\cargo-tracker-manifests" rmdir /s /q "%TEMP%\cargo-tracker-manifests"
xcopy /s /e /i /q "%MANIFESTS_DIR%" "%TEMP%\cargo-tracker-manifests"

REM Replace placeholders using PowerShell
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml') -replace '\{\{IMAGE_URI\}\}', '!IMAGE_URI!' | Set-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml') -replace '\{\{DB_JDBC_URL\}\}', '!DB_JDBC_URL_VAL!' | Set-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml') -replace '\{\{DB_USER\}\}', '!DB_USER_VAL!' | Set-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml') -replace '\{\{DB_PASSWORD\}\}', '!DB_PASSWORD_VAL!' | Set-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml') -replace '\{\{GRAPH_TRAVERSAL_URL\}\}', '!GRAPH_TRAVERSAL_URL_VAL!' | Set-Content '%TEMP%\cargo-tracker-manifests\deployment.yaml'"

echo.
echo --- Applying Kubernetes manifests ---

echo Applying namespace...
kubectl apply -f "%TEMP%\cargo-tracker-manifests\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    exit /b 1
)

echo Applying deployment...
kubectl apply -f "%TEMP%\cargo-tracker-manifests\deployment.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    exit /b 1
)

echo Applying service...
kubectl apply -f "%TEMP%\cargo-tracker-manifests\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    exit /b 1
)

echo Applying ingress...
kubectl apply -f "%TEMP%\cargo-tracker-manifests\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    exit /b 1
)

echo.
echo --- Waiting for deployment rollout ---
kubectl rollout status deployment/%APP_NAME% -n %NAMESPACE% --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed. Rolling back...
    kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%
    echo Rollback initiated. Check pod status:
    kubectl get pods -n %NAMESPACE%
    exit /b 1
)

echo.
echo --- Verifying deployed resources ---
kubectl get pods,svc,ingress -n %NAMESPACE%

echo.
echo ==============================================
echo   DEPLOYMENT SUCCESSFUL!
echo ==============================================
echo.
echo   Application: %APP_NAME%
echo   Namespace:   %NAMESPACE%
echo   Image:       !IMAGE_URI!
echo.
echo   To check pod logs:
echo     kubectl logs -l app=%APP_NAME% -n %NAMESPACE% --tail=100
echo.
echo   To rollback if needed:
echo     kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%
echo.

REM Cleanup temp manifests
rmdir /s /q "%TEMP%\cargo-tracker-manifests"

endlocal

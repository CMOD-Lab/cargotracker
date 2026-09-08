@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy cargo-tracker to Azure AKS
REM ============================================================

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker

echo ============================================
echo  Deploy to Azure AKS - %APP_NAME%
echo ============================================
echo.

REM ---- Prompt for Azure details ----
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

set /p IMAGE_URI="Enter full Docker image URI (e.g., myregistry.azurecr.io/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI cannot be empty.
    exit /b 1
)

echo.
echo ---- Application Configuration ----
set /p DB_JDBC_URL="Enter DB_JDBC_URL (e.g., jdbc:postgresql://host:5432/postgres): "
if "!DB_JDBC_URL!"=="" (
    set DB_JDBC_URL=jdbc:postgresql://localhost:5432/postgres
    echo Using default: !DB_JDBC_URL!
)

set /p DB_USERNAME="Enter DB_USERNAME (press Enter for 'postgres'): "
if "!DB_USERNAME!"=="" (
    set DB_USERNAME=postgres
)

set /p DB_PASSWORD="Enter DB_PASSWORD (press Enter for 'postgres'): "
if "!DB_PASSWORD!"=="" (
    set DB_PASSWORD=postgres
)

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL (press Enter for default): "
if "!GRAPH_TRAVERSAL_URL!"=="" (
    set GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
)

echo.
echo ---- Configuring kubectl for AKS ----
az aks get-credentials --resource-group !RESOURCE_GROUP! --name !CLUSTER_NAME! --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to get AKS credentials. Check resource group and cluster name.
    exit /b 1
)

echo.
echo ---- Verifying cluster connectivity ----
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

echo.
echo ---- Updating Kubernetes manifests ----

REM Create backup of deployment.yaml
copy /Y kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul

REM Replace placeholders using PowerShell
powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '\{\{IMAGE_URI\}\}', '!IMAGE_URI!' | Set-Content 'kubernetes\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '\{\{DB_JDBC_URL\}\}', '!DB_JDBC_URL!' | Set-Content 'kubernetes\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '\{\{DB_USERNAME\}\}', '!DB_USERNAME!' | Set-Content 'kubernetes\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '\{\{DB_PASSWORD\}\}', '!DB_PASSWORD!' | Set-Content 'kubernetes\deployment.yaml'"
powershell -Command "(Get-Content 'kubernetes\deployment.yaml') -replace '\{\{GRAPH_TRAVERSAL_URL\}\}', '!GRAPH_TRAVERSAL_URL!' | Set-Content 'kubernetes\deployment.yaml'"

echo Manifests updated successfully.

echo.
echo ---- Applying Kubernetes manifests ----

echo Applying namespace...
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    copy /Y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
    exit /b 1
)

echo Applying deployment...
kubectl apply -f kubernetes\deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    copy /Y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
    exit /b 1
)

echo Applying service...
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    copy /Y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
    exit /b 1
)

echo Applying ingress...
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    copy /Y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
    exit /b 1
)

echo.
echo ---- Waiting for deployment rollout ----
kubectl rollout status deployment/%APP_NAME% -n %NAMESPACE% --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed or timed out.
    echo To rollback, run: kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%
    copy /Y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
    exit /b 1
)

REM Restore original manifest with placeholders
copy /Y kubernetes\deployment.yaml.bak kubernetes\deployment.yaml >nul
del kubernetes\deployment.yaml.bak >nul 2>&1

echo.
echo ---- Verifying deployed resources ----
kubectl get pods,svc,ingress -n %NAMESPACE%

echo.
echo ============================================
echo  SUCCESS: %APP_NAME% deployed to AKS!
echo ============================================
echo.
echo Useful commands:
echo   kubectl get pods -n %NAMESPACE%
echo   kubectl logs -f deployment/%APP_NAME% -n %NAMESPACE%
echo   kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%

endlocal

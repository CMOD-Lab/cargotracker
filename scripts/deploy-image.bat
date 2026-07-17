@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: deploy-image.bat - Deploy cargo-tracker to Azure AKS
:: ============================================================

set "APP_NAME=cargo-tracker"
set "NAMESPACE=cargo-tracker"
set "MANIFESTS_DIR=kubernetes"

echo ==============================================
echo   Deploy %APP_NAME% to Azure AKS
echo ==============================================

:: ---- Prompt for Azure details ----
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
echo ---- Application Environment Variables ----
set /p "POSTGRESQL_JDBC_URL=Enter POSTGRESQL_JDBC_URL (or press Enter to skip): "
set /p "POSTGRESQL_USERNAME=Enter POSTGRESQL_USERNAME (or press Enter to skip): "
set /p "POSTGRESQL_PASSWORD=Enter POSTGRESQL_PASSWORD (or press Enter to skip): "

:: ---- Configure kubectl for AKS ----
echo.
echo Configuring kubectl for AKS cluster: !CLUSTER_NAME!...
az aks get-credentials --resource-group "!RESOURCE_GROUP!" --name "!CLUSTER_NAME!" --overwrite-existing
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for AKS.
    exit /b 1
)
echo kubectl configured successfully.

:: ---- Verify cluster connectivity ----
echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to AKS cluster.
    exit /b 1
)

:: ---- Create working copies of manifests ----
echo.
echo Updating Kubernetes manifests with deployment values...

set "WORK_DIR=%TEMP%\cargo-tracker-deploy"
if exist "!WORK_DIR!" rmdir /s /q "!WORK_DIR!"
mkdir "!WORK_DIR!"
xcopy /s /q "%MANIFESTS_DIR%\*" "!WORK_DIR!\" >nul

:: Replace IMAGE_URI placeholder using PowerShell
powershell -NoProfile -Command "(Get-Content '!WORK_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!WORK_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to update IMAGE_URI in deployment.yaml.
    exit /b 1
)

:: Replace POSTGRESQL_JDBC_URL
if "!POSTGRESQL_JDBC_URL!"=="" set "POSTGRESQL_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database"
powershell -NoProfile -Command "(Get-Content '!WORK_DIR!\deployment.yaml') -replace '{{POSTGRESQL_JDBC_URL}}', '!POSTGRESQL_JDBC_URL!' | Set-Content '!WORK_DIR!\deployment.yaml'"

:: Replace POSTGRESQL_USERNAME
powershell -NoProfile -Command "(Get-Content '!WORK_DIR!\deployment.yaml') -replace '{{POSTGRESQL_USERNAME}}', '!POSTGRESQL_USERNAME!' | Set-Content '!WORK_DIR!\deployment.yaml'"

:: Replace POSTGRESQL_PASSWORD
powershell -NoProfile -Command "(Get-Content '!WORK_DIR!\deployment.yaml') -replace '{{POSTGRESQL_PASSWORD}}', '!POSTGRESQL_PASSWORD!' | Set-Content '!WORK_DIR!\deployment.yaml'"

echo Manifests updated.

:: ---- Apply Kubernetes manifests ----
echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "!WORK_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.yaml
    exit /b 1
)

echo   [2/4] Applying deployment...
kubectl apply -f "!WORK_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.yaml
    exit /b 1
)

echo   [3/4] Applying service...
kubectl apply -f "!WORK_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.yaml
    exit /b 1
)

echo   [4/4] Applying ingress...
kubectl apply -f "!WORK_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.yaml
    exit /b 1
)

:: ---- Wait for rollout ----
echo.
echo Waiting for deployment rollout to complete...
kubectl rollout status deployment/%APP_NAME% -n %NAMESPACE% --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo WARNING: Rollout did not complete within timeout. Check pod status manually.
)

:: ---- Verify resources ----
echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n %NAMESPACE%

:: ---- Display application URL ----
echo.
echo Fetching application ingress URL...
for /f "delims=" %%i in ('kubectl get ingress %APP_NAME%-ingress -n %NAMESPACE% -o jsonpath^="{.spec.rules[0].host}" 2^>nul') do set "INGRESS_HOST=%%i"
if "!INGRESS_HOST!" neq "" (
    echo Application URL: http://!INGRESS_HOST!/
) else (
    echo Ingress host not yet assigned. Check: kubectl get ingress -n %NAMESPACE%
)

:: ---- Cleanup ----
if exist "!WORK_DIR!" rmdir /s /q "!WORK_DIR!"

echo.
echo ==============================================
echo   Deployment complete!
echo   App: %APP_NAME%
echo   Namespace: %NAMESPACE%
echo   Image: !IMAGE_URI!
echo ==============================================
echo.
echo Rollback command (if needed):
echo   kubectl rollout undo deployment/%APP_NAME% -n %NAMESPACE%

endlocal

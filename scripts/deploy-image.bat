@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: deploy-image.bat - Deploy cargo-tracker to AWS EKS (Windows)
:: ============================================================

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker
set K8S_DIR=kubernetes
set TEMP_DIR=%TEMP%\cargo-tracker-k8s-deploy

echo ==============================================
echo   cargo-tracker - AWS EKS Deployment Script
echo ==============================================
echo.

:: Prompt for AWS configuration
set /p AWS_REGION="Enter AWS Region (e.g. us-east-1): "
if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)

set /p CLUSTER_NAME="Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: EKS Cluster Name is required.
    exit /b 1
)

set /p IMAGE_URI="Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

echo.
echo --- Optional Application Configuration ---
echo (Press Enter to skip any value and use defaults)
echo.

set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL [http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path]: "
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path

set /p DB_JDBC_URL="Enter DB_JDBC_URL [jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database]: "
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database

set /p DB_USER="Enter DB_USER []: "
set /p DB_PASSWORD="Enter DB_PASSWORD []: "

echo.
echo ==============================================
echo   Configuring kubectl for EKS cluster...
echo ==============================================
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for EKS cluster.
    exit /b 1
)

echo.
echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to EKS cluster.
    exit /b 1
)

echo.
echo ==============================================
echo   Updating Kubernetes manifests...
echo ==============================================

:: Create temp working directory
if exist "!TEMP_DIR!" rmdir /s /q "!TEMP_DIR!"
mkdir "!TEMP_DIR!"
xcopy /s /e /q "%K8S_DIR%\*" "!TEMP_DIR!\" >nul

:: Replace placeholders using PowerShell
powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to update IMAGE_URI. & exit /b 1 )

powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to update GRAPH_TRAVERSAL_URL. & exit /b 1 )

powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to update DB_JDBC_URL. & exit /b 1 )

powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_USER}}', '!DB_USER!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to update DB_USER. & exit /b 1 )

powershell -Command "(Get-Content '!TEMP_DIR!\deployment.yaml') -replace '{{DB_PASSWORD}}', '!DB_PASSWORD!' | Set-Content '!TEMP_DIR!\deployment.yaml'"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to update DB_PASSWORD. & exit /b 1 )

echo Manifests updated successfully.

echo.
echo ==============================================
echo   Applying Kubernetes manifests...
echo ==============================================

echo Applying namespace...
kubectl apply -f "!TEMP_DIR!\namespace.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply namespace. & exit /b 1 )

echo Applying deployment...
kubectl apply -f "!TEMP_DIR!\deployment.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply deployment. & exit /b 1 )

echo Applying service...
kubectl apply -f "!TEMP_DIR!\service.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply service. & exit /b 1 )

echo Applying ingress...
kubectl apply -f "!TEMP_DIR!\ingress.yaml"
if !ERRORLEVEL! neq 0 ( echo ERROR: Failed to apply ingress. & exit /b 1 )

echo.
echo ==============================================
echo   Waiting for deployment rollout...
echo ==============================================
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo.
    echo ERROR: Deployment rollout failed or timed out.
    echo To rollback, run: kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    exit /b 1
)

echo.
echo ==============================================
echo   Verifying deployed resources...
echo ==============================================
kubectl get pods,svc,ingress -n !NAMESPACE!

echo.
echo ==============================================
echo   Deployment completed successfully!
echo   Namespace: !NAMESPACE!
echo   Image:     !IMAGE_URI!
echo ==============================================

:: Cleanup temp files
rmdir /s /q "!TEMP_DIR!"

endlocal

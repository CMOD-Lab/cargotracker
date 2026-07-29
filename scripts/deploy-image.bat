@echo off
setlocal enabledelayedexpansion

set APP_NAME=cargo-tracker
set NAMESPACE=cargo-tracker
set K8S_DIR=kubernetes

echo ============================================
echo   Cargo Tracker - Deploy to AWS EKS
echo ============================================
echo.

rem Prompt for AWS region
set /p AWS_REGION="Enter AWS Region (e.g., us-east-1): "
if "!AWS_REGION!"=="" (
    echo ERROR: AWS Region is required.
    exit /b 1
)

rem Prompt for EKS cluster name
set /p CLUSTER_NAME="Enter EKS Cluster Name: "
if "!CLUSTER_NAME!"=="" (
    echo ERROR: EKS Cluster Name is required.
    exit /b 1
)

rem Prompt for Docker image URI
set /p IMAGE_URI="Enter full Docker image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Docker image URI is required.
    exit /b 1
)

rem Prompt for application-specific environment variables
echo.
echo --- Application Configuration (press Enter to skip) ---
set /p GRAPH_TRAVERSAL_URL_VAL="Enter GRAPH_TRAVERSAL_URL (e.g., http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path): "
if "!GRAPH_TRAVERSAL_URL_VAL!"=="" (
    set GRAPH_TRAVERSAL_URL_VAL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
)

set /p DB_JDBC_URL_VAL="Enter DB_JDBC_URL (e.g., jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database): "
if "!DB_JDBC_URL_VAL!"=="" (
    set DB_JDBC_URL_VAL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
)

set /p DB_USER_VAL="Enter DB_USER (press Enter to skip): "
set /p DB_PASSWORD_VAL="Enter DB_PASSWORD (press Enter to skip): "

echo.
echo Configuring kubectl for EKS cluster: !CLUSTER_NAME! in !AWS_REGION!...
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to configure kubectl for EKS cluster.
    exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo ERROR: Cannot connect to Kubernetes cluster.
    exit /b 1
)

echo.
echo Updating Kubernetes manifests with deployment values...

rem Create temp directory for modified manifests
if exist "%TEMP%\cargo-tracker-k8s-deploy" rmdir /s /q "%TEMP%\cargo-tracker-k8s-deploy"
xcopy /s /e /i /q "%K8S_DIR%" "%TEMP%\cargo-tracker-k8s-deploy"

rem Replace placeholders using PowerShell
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml') -replace '{{GRAPH_TRAVERSAL_URL}}', '!GRAPH_TRAVERSAL_URL_VAL!' | Set-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml') -replace '{{DB_JDBC_URL}}', '!DB_JDBC_URL_VAL!' | Set-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml') -replace '{{DB_USER}}', '!DB_USER_VAL!' | Set-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml'"
powershell -Command "(Get-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml') -replace '{{DB_PASSWORD}}', '!DB_PASSWORD_VAL!' | Set-Content '%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml'"

echo.
echo Applying Kubernetes manifests...

echo   [1/4] Applying namespace...
kubectl apply -f "%TEMP%\cargo-tracker-k8s-deploy\namespace.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply namespace.
    exit /b 1
)

echo   [2/4] Applying deployment...
kubectl apply -f "%TEMP%\cargo-tracker-k8s-deploy\deployment.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply deployment.
    exit /b 1
)

echo   [3/4] Applying service...
kubectl apply -f "%TEMP%\cargo-tracker-k8s-deploy\service.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply service.
    exit /b 1
)

echo   [4/4] Applying ingress...
kubectl apply -f "%TEMP%\cargo-tracker-k8s-deploy\ingress.yaml"
if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to apply ingress.
    exit /b 1
)

echo.
echo Waiting for deployment rollout...
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=300s
if !ERRORLEVEL! neq 0 (
    echo ERROR: Deployment rollout failed. Rolling back...
    kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
    echo Rollback initiated. Check pod status with: kubectl get pods -n !NAMESPACE!
    exit /b 1
)

echo.
echo Verifying deployed resources...
kubectl get pods,svc,ingress -n !NAMESPACE!

rem Cleanup temp files
rmdir /s /q "%TEMP%\cargo-tracker-k8s-deploy"

echo.
echo ============================================
echo   Deployment to AWS EKS completed!
echo   Namespace: !NAMESPACE!
echo   Image: !IMAGE_URI!
echo ============================================
echo.
echo Useful commands:
echo   kubectl get pods -n !NAMESPACE!
echo   kubectl logs -f deployment/!APP_NAME! -n !NAMESPACE!
echo   kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!

endlocal

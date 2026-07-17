@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM deploy-image.bat - Deploy cargo-tracker to GCP GKE
REM ============================================================

echo ============================================================
echo   cargo-tracker - GCP GKE Deployment
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

set /p IMAGE_URI="Enter full Docker image URI (e.g., us-central1-docker.pkg.dev/my-project/my-repo/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
  echo ERROR: Docker image URI is required.
  exit /b 1
)

echo.
echo --- Optional: Application Environment Variables ---
echo (Press Enter to skip any variable)
echo.

set /p DB_JDBC_URL="Enter DB_JDBC_URL (database JDBC URL): "
set /p DB_DRIVER_CLASS="Enter DB_DRIVER_CLASS (JDBC driver class): "
set /p DB_USER="Enter DB_USER (database username): "
set /p DB_PASSWORD="Enter DB_PASSWORD (database password): "
set /p GRAPH_TRAVERSAL_URL="Enter GRAPH_TRAVERSAL_URL (graph traversal service URL): "

echo.
echo ============================================================
echo   Configuring kubectl for GKE cluster: !CLUSTER_NAME!
echo ============================================================

gcloud config set project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
  echo ERROR: gcloud config set project failed.
  exit /b 1
)

gcloud container clusters get-credentials !CLUSTER_NAME! --zone !GCP_ZONE! --project !GCP_PROJECT!
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to get GKE cluster credentials.
  exit /b 1
)

echo Verifying cluster connectivity...
kubectl cluster-info
if !ERRORLEVEL! neq 0 (
  echo ERROR: Cannot connect to cluster.
  exit /b 1
)

echo.
echo ============================================================
echo   Updating Kubernetes manifests with deployment values
echo ============================================================

set MANIFEST_DIR=kubernetes

REM Update IMAGE_URI placeholder
powershell -Command "(Get-Content '%MANIFEST_DIR%\deployment.yaml') -replace '\{\{IMAGE_URI\}\}', '!IMAGE_URI!' | Set-Content '%MANIFEST_DIR%\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to update IMAGE_URI in deployment.yaml.
  exit /b 1
)

REM Update DB_JDBC_URL
if "!DB_JDBC_URL!"=="" set DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database
powershell -Command "(Get-Content '%MANIFEST_DIR%\deployment.yaml') -replace '\{\{DB_JDBC_URL\}\}', '!DB_JDBC_URL!' | Set-Content '%MANIFEST_DIR%\deployment.yaml'"

REM Update DB_DRIVER_CLASS
if "!DB_DRIVER_CLASS!"=="" set DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource
powershell -Command "(Get-Content '%MANIFEST_DIR%\deployment.yaml') -replace '\{\{DB_DRIVER_CLASS\}\}', '!DB_DRIVER_CLASS!' | Set-Content '%MANIFEST_DIR%\deployment.yaml'"

REM Update DB_USER
powershell -Command "(Get-Content '%MANIFEST_DIR%\deployment.yaml') -replace '\{\{DB_USER\}\}', '!DB_USER!' | Set-Content '%MANIFEST_DIR%\deployment.yaml'"

REM Update DB_PASSWORD
powershell -Command "(Get-Content '%MANIFEST_DIR%\deployment.yaml') -replace '\{\{DB_PASSWORD\}\}', '!DB_PASSWORD!' | Set-Content '%MANIFEST_DIR%\deployment.yaml'"

REM Update GRAPH_TRAVERSAL_URL
if "!GRAPH_TRAVERSAL_URL!"=="" set GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path
powershell -Command "(Get-Content '%MANIFEST_DIR%\deployment.yaml') -replace '\{\{GRAPH_TRAVERSAL_URL\}\}', '!GRAPH_TRAVERSAL_URL!' | Set-Content '%MANIFEST_DIR%\deployment.yaml'"

echo Manifests updated successfully.

echo.
echo ============================================================
echo   Applying Kubernetes manifests
echo ============================================================

echo Applying namespace...
kubectl apply -f %MANIFEST_DIR%\namespace.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply namespace.yaml.
  exit /b 1
)

echo Applying deployment...
kubectl apply -f %MANIFEST_DIR%\deployment.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply deployment.yaml.
  exit /b 1
)

echo Applying service...
kubectl apply -f %MANIFEST_DIR%\service.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply service.yaml.
  exit /b 1
)

echo Applying ingress...
kubectl apply -f %MANIFEST_DIR%\ingress.yaml
if !ERRORLEVEL! neq 0 (
  echo ERROR: Failed to apply ingress.yaml.
  exit /b 1
)

echo.
echo ============================================================
echo   Waiting for deployment rollout...
echo ============================================================
kubectl rollout status deployment/cargo-tracker -n cargo-tracker --timeout=300s
if !ERRORLEVEL! neq 0 (
  echo ERROR: Deployment rollout failed or timed out.
  echo To rollback: kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
  exit /b 1
)

echo.
echo ============================================================
echo   Verifying deployed resources
echo ============================================================
kubectl get pods,svc,ingress -n cargo-tracker

echo.
echo ============================================================
echo   Deployment complete!
echo.
echo   Useful commands:
echo   kubectl get pods -n cargo-tracker
echo   kubectl logs -f deployment/cargo-tracker -n cargo-tracker
echo   kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
echo ============================================================

endlocal

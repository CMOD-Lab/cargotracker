# Cargo Tracker Deployment Guide

## Overview
This project is a Jakarta EE 10 Maven web application packaged as a WAR and intended to run on Azure AKS using a single application container. The container embeds Payara Micro at runtime and deploys the generated `cargo-tracker.war`.

## Prerequisites
- Java 11 compatible environment for local Maven packaging
- Docker Desktop or Docker Engine
- Azure CLI authenticated to the target subscription
- kubectl configured locally
- Access to an Azure Container Registry or Docker Hub
- PostgreSQL database reachable from AKS

## Application Characteristics
- Build tool: Maven
- Java version: 11
- Package type: WAR
- Runtime server: Payara Micro
- Application port: 8080
- Context root: /
- Persistence: PostgreSQL for cloud profile
- Additional application dependency: graph traversal REST endpoint

## Files Generated
- `Dockerfile`
- `.dockerignore`
- `docker-compose.yml`
- `scripts/build-push.sh`
- `scripts/build-push.bat`
- `scripts/deploy-image.sh`
- `scripts/deploy-image.bat`
- `kubernetes/namespace.yaml`
- `kubernetes/deployment.yaml`
- `kubernetes/service.yaml`
- `kubernetes/ingress.yaml`

## Local Docker Compose Usage
1. Ensure PostgreSQL is available externally.
2. Optionally create `config` and `secrets` directories in the repository root.
3. Export environment variables as needed:
   - `POSTGRESQL_JDBC_URL`
   - `POSTGRESQL_USERNAME`
   - `POSTGRESQL_PASSWORD`
   - `GRAPH_TRAVERSAL_URL`
4. Start the application:
   ```bash
   docker compose up --build
   ```
5. Access the app at `http://localhost:8080`.

## Build and Push Image
### Linux/macOS
```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```
The script prompts for registry selection, credentials, and image tag, then builds and pushes the image.

### Windows
```bat
scripts\build-push.bat
```
The batch script provides the same workflow for ACR or Docker Hub.

## Azure AKS Deployment
### 1. Prepare Azure
- Log in with `az login`
- Confirm the correct subscription with `az account set --subscription <subscription-id>`
- Ensure AKS and ingress controller are provisioned

### 2. Push the image
Use one of the generated build/push scripts and note the full image URI.

### 3. Deploy to AKS
#### Linux/macOS
```bash
chmod +x scripts/deploy-image.sh
./scripts/deploy-image.sh
```
#### Windows
```bat
scripts\deploy-image.bat
```
You will be prompted for:
- Azure resource group
- AKS cluster name
- Full Docker image URI
- `POSTGRESQL_JDBC_URL`
- `POSTGRESQL_USERNAME`
- `POSTGRESQL_PASSWORD`
- `GRAPH_TRAVERSAL_URL`

### 4. Verify deployment
```bash
kubectl get pods,svc,ingress -n cargo-tracker
kubectl rollout status deployment/cargo-tracker -n cargo-tracker
```

## Kubernetes Manifest Notes
- Namespace: `cargo-tracker`
- Deployment replicas: 2
- Service type: ClusterIP
- Ingress class: `azure/application-gateway`
- Probes: TCP socket on port 8080 because no native health endpoint was detected in the application codebase

## Configuration Management
Provide sensitive values through secure secret management in production. The generated manifests use placeholders so that deployment scripts can inject runtime values. Recommended production improvement:
- Replace plaintext environment values with Kubernetes Secrets
- Use ConfigMaps for non-sensitive configuration
- Store database credentials in Azure Key Vault and sync into AKS

## Security Considerations
- Container runs as a non-root user
- Keep registry credentials out of source control
- Rotate database passwords regularly
- Restrict ingress hostnames and TLS settings in production
- Add network policies if your AKS cluster supports them

## Troubleshooting
### Pod fails to start
- Check logs:
  ```bash
  kubectl logs deployment/cargo-tracker -n cargo-tracker
  ```
- Verify image URI is accessible
- Confirm PostgreSQL connectivity from the cluster

### Readiness probe failures
- Because readiness uses TCP on port 8080, failures usually indicate the app server has not finished starting or the process exited
- Increase initial delay if startup is slow in your environment

### Ingress not reachable
- Confirm AGIC is installed and healthy
- Verify DNS points to the Application Gateway frontend
- Inspect ingress events:
  ```bash
  kubectl describe ingress cargo-tracker-ingress -n cargo-tracker
  ```

### Rollback
```bash
kubectl rollout undo deployment/cargo-tracker -n cargo-tracker
```

## Scaling and Operations
- Scale manually:
  ```bash
  kubectl scale deployment/cargo-tracker --replicas=3 -n cargo-tracker
  ```
- Review rollout history:
  ```bash
  kubectl rollout history deployment/cargo-tracker -n cargo-tracker
  ```
- Consider adding HPA after collecting CPU and memory metrics

## Java Runtime Notes
- JVM options are set for container awareness and bounded heap usage
- Timezone is set to UTC
- Charset is pinned to UTF-8
- Runtime image uses the explicit base image requested: `mcr.microsoft.com/openjdk/jdk:11-ubuntu`

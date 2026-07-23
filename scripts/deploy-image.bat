@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM deploy-image.bat - Deploy cargo-tracker to AWS ECS Fargate (Windows)
REM Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro
REM =============================================================================

set PROJECT_NAME=cargo-tracker
set TASK_FAMILY=cargo-tracker-task
set SERVICE_NAME=cargo-tracker-service
set CONTAINER_NAME=cargo-tracker
set CONTAINER_PORT=8080
set LOG_GROUP=/ecs/cargo-tracker
set TASK_DEF_FILE=ecs\task-definition.json
set SERVICE_DEF_FILE=ecs\service-definition.json

echo ==============================================
echo   cargo-tracker - AWS ECS Fargate Deployment
echo ==============================================
echo.

REM ---- Collect configuration ----
set /p AWS_REGION="Enter AWS Region [us-east-1]: "
if "!AWS_REGION!"=="" set AWS_REGION=us-east-1

set /p CLUSTER_NAME="Enter ECS Cluster name [cargo-tracker-cluster]: "
if "!CLUSTER_NAME!"=="" set CLUSTER_NAME=cargo-tracker-cluster

set /p IMAGE_URI="Enter ECR Image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI is required.
    exit /b 1
)

set /p VPC_ID="Enter VPC ID (e.g., vpc-xxxxxxxx): "
if "!VPC_ID!"=="" (
    echo ERROR: VPC ID is required.
    exit /b 1
)

set /p SUBNETS_INPUT="Enter Subnet IDs (comma-separated, e.g., subnet-aaa,subnet-bbb): "
if "!SUBNETS_INPUT!"=="" (
    echo ERROR: At least one subnet ID is required.
    exit /b 1
)

set /p SECURITY_GROUP="Enter Security Group ID (e.g., sg-xxxxxxxx): "
if "!SECURITY_GROUP!"=="" (
    echo ERROR: Security Group ID is required.
    exit /b 1
)

REM Parse subnets
for /f "tokens=1,2 delims=," %%a in ("!SUBNETS_INPUT!") do (
    set SUBNET_1=%%a
    set SUBNET_2=%%b
)
if "!SUBNET_2!"=="" set SUBNET_2=!SUBNET_1!

REM Remove spaces from subnets
set SUBNET_1=!SUBNET_1: =!
set SUBNET_2=!SUBNET_2: =!

REM ---- Get AWS Account ID ----
echo.
echo Retrieving AWS Account ID...
for /f "delims=" %%i in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%i
if "!ACCOUNT_ID!"=="" (
    echo ERROR: Could not retrieve AWS Account ID. Ensure AWS CLI is configured.
    exit /b 1
)
echo AWS Account ID: !ACCOUNT_ID!

REM ---- Ensure CloudWatch Log Group exists ----
echo.
echo Ensuring CloudWatch log group exists...
aws logs create-log-group --log-group-name "!LOG_GROUP!" --region !AWS_REGION! >nul 2>&1
echo Log group ready.

REM ---- Ensure ECS Cluster exists ----
echo.
echo Checking ECS cluster...
for /f "delims=" %%i in ('aws ecs describe-clusters --clusters !CLUSTER_NAME! --region !AWS_REGION! --query "clusters[0].status" --output text 2^>nul') do set CLUSTER_STATUS=%%i
if not "!CLUSTER_STATUS!"=="ACTIVE" (
    echo Creating ECS cluster !CLUSTER_NAME!...
    aws ecs create-cluster --cluster-name !CLUSTER_NAME! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECS cluster.
        exit /b 1
    )
    echo Cluster created.
) else (
    echo Cluster !CLUSTER_NAME! is ACTIVE.
)

REM ---- Load Balancer ----
echo.
set /p NEED_LB="Do you need an Application Load Balancer for this service? (y/n) [n]: "
if "!NEED_LB!"=="" set NEED_LB=n

set TARGET_GROUP_ARN=
set ALB_DNS=

if /i "!NEED_LB!"=="y" (
    echo.
    echo Creating Application Load Balancer...

    for /f "delims=" %%i in ('aws elbv2 create-load-balancer --name cargo-tracker-alb --subnets !SUBNET_1! !SUBNET_2! --security-groups !SECURITY_GROUP! --scheme internet-facing --type application --region !AWS_REGION! --query "LoadBalancers[0].LoadBalancerArn" --output text') do set ALB_ARN=%%i
    echo ALB created: !ALB_ARN!

    for /f "delims=" %%i in ('aws elbv2 describe-load-balancers --load-balancer-arns !ALB_ARN! --region !AWS_REGION! --query "LoadBalancers[0].DNSName" --output text') do set ALB_DNS=%%i

    for /f "delims=" %%i in ('aws elbv2 create-target-group --name cargo-tracker-tg --protocol HTTP --port !CONTAINER_PORT! --vpc-id !VPC_ID! --target-type ip --health-check-path "/rest/health" --health-check-interval-seconds 30 --health-check-timeout-seconds 10 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --region !AWS_REGION! --query "TargetGroups[0].TargetGroupArn" --output text') do set TARGET_GROUP_ARN=%%i
    echo Target Group created: !TARGET_GROUP_ARN!

    aws elbv2 create-listener --load-balancer-arn !ALB_ARN! --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=!TARGET_GROUP_ARN! --region !AWS_REGION! >nul
    echo ALB Listener created on port 80.
)

REM ---- Prepare task definition ----
echo.
echo Preparing task definition...
copy /Y "!TASK_DEF_FILE!" "%TEMP%\task-definition-deploy.json" >nul

powershell -Command "(Get-Content '%TEMP%\task-definition-deploy.json') -replace '{{ACCOUNT_ID}}', '!ACCOUNT_ID!' -replace '{{AWS_REGION}}', '!AWS_REGION!' -replace '{{IMAGE_URI}}', '!IMAGE_URI!' | Set-Content '%TEMP%\task-definition-deploy.json'"

REM ---- Register task definition ----
echo Registering ECS task definition...
for /f "delims=" %%i in ('aws ecs register-task-definition --cli-input-json file://%TEMP%\task-definition-deploy.json --region !AWS_REGION! --query "taskDefinition.taskDefinitionArn" --output text') do set TASK_DEF_ARN=%%i
if "!TASK_DEF_ARN!"=="" (
    echo ERROR: Failed to register task definition.
    exit /b 1
)
echo Task definition registered: !TASK_DEF_ARN!

REM ---- Prepare service definition ----
echo.
echo Preparing service definition...
copy /Y "!SERVICE_DEF_FILE!" "%TEMP%\service-definition-deploy.json" >nul

powershell -Command "(Get-Content '%TEMP%\service-definition-deploy.json') -replace '{{CLUSTER_NAME}}', '!CLUSTER_NAME!' -replace '{{SUBNET_1}}', '!SUBNET_1!' -replace '{{SUBNET_2}}', '!SUBNET_2!' -replace '{{SECURITY_GROUP}}', '!SECURITY_GROUP!' | Set-Content '%TEMP%\service-definition-deploy.json'"

REM ---- Check if service exists ----
echo.
echo Checking if ECS service exists...
for /f "delims=" %%i in ('aws ecs describe-services --cluster !CLUSTER_NAME! --services !SERVICE_NAME! --region !AWS_REGION! --query "services[?status!='INACTIVE'].serviceName" --output text 2^>nul') do set EXISTING_SERVICE=%%i

if "!EXISTING_SERVICE!"=="" (
    echo Creating new ECS service !SERVICE_NAME!...
    aws ecs create-service --cli-input-json file://%TEMP%\service-definition-deploy.json --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECS service.
        exit /b 1
    )
    echo Service created.
) else (
    echo Updating existing ECS service !SERVICE_NAME!...
    aws ecs update-service --cluster !CLUSTER_NAME! --service !SERVICE_NAME! --task-definition !TASK_DEF_ARN! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to update ECS service.
        exit /b 1
    )
    echo Service updated.
)

REM ---- Wait for service stability ----
echo.
echo Waiting for service to become stable (this may take several minutes)...
aws ecs wait services-stable --cluster !CLUSTER_NAME! --services !SERVICE_NAME! --region !AWS_REGION!
if !ERRORLEVEL! neq 0 (
    echo WARNING: Service did not stabilize within the expected time. Check ECS console.
)

REM ---- Verify deployment ----
echo.
echo ==============================================
echo   Deployment Verification
echo ==============================================
aws ecs describe-services --cluster !CLUSTER_NAME! --services !SERVICE_NAME! --region !AWS_REGION! --query "services[0].{ServiceName:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount}" --output table

echo.
echo CloudWatch Log Group: !LOG_GROUP!
echo View logs: aws logs tail !LOG_GROUP! --follow --region !AWS_REGION!

if not "!ALB_DNS!"=="" (
    echo.
    echo Application Load Balancer DNS: http://!ALB_DNS!
    echo Health Check URL: http://!ALB_DNS!/rest/health
)

echo.
echo ==============================================
echo   Deployment Complete!
echo ==============================================
echo.
echo Troubleshooting tips:
echo   - View tasks: aws ecs list-tasks --cluster !CLUSTER_NAME! --region !AWS_REGION!
echo   - View logs: aws logs tail !LOG_GROUP! --follow --region !AWS_REGION!
echo   - Check security group allows inbound TCP on port !CONTAINER_PORT!

endlocal

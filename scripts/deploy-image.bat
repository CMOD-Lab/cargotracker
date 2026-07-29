@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM deploy-image.bat - Deploy CareTracker to AWS ECS Fargate (Windows)
REM =============================================================================

set "SERVICE_NAME=cargo-tracker-service"
set "TASK_FAMILY=cargo-tracker-task"
set "PROJECT_NAME=cargo-tracker"
set "LOG_GROUP=/ecs/cargo-tracker"

echo ==============================================
echo   CareTracker - AWS ECS Fargate Deployment
echo ==============================================
echo.

REM ---- Gather configuration ----
set /p "AWS_REGION=Enter AWS Region [us-east-1]: "
if "!AWS_REGION!"=="" set "AWS_REGION=us-east-1"

set /p "CLUSTER_NAME=Enter ECS Cluster name [cargo-tracker-cluster]: "
if "!CLUSTER_NAME!"=="" set "CLUSTER_NAME=cargo-tracker-cluster"

set /p "IMAGE_URI=Enter ECR Image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): "
if "!IMAGE_URI!"=="" (
    echo ERROR: Image URI is required.
    exit /b 1
)

set /p "VPC_ID=Enter VPC ID (e.g. vpc-xxxxxxxx): "
if "!VPC_ID!"=="" (
    echo ERROR: VPC ID is required.
    exit /b 1
)

set /p "SUBNETS_INPUT=Enter Subnet IDs comma-separated (e.g. subnet-aaa,subnet-bbb): "
if "!SUBNETS_INPUT!"=="" (
    echo ERROR: At least one subnet is required.
    exit /b 1
)

REM Parse subnets
for /f "tokens=1,2 delims=," %%a in ("!SUBNETS_INPUT!") do (
    set "SUBNET_1=%%a"
    set "SUBNET_2=%%b"
)
if "!SUBNET_2!"=="" set "SUBNET_2=!SUBNET_1!"

set /p "SECURITY_GROUP=Enter Security Group ID (e.g. sg-xxxxxxxx): "
if "!SECURITY_GROUP!"=="" (
    echo ERROR: Security Group ID is required.
    exit /b 1
)

REM ---- Get AWS Account ID ----
echo.
echo Fetching AWS Account ID...
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text 2^>^&1') do set "ACCOUNT_ID=%%i"
echo Account ID: !ACCOUNT_ID!

REM ---- Ensure CloudWatch log group exists ----
echo.
echo Ensuring CloudWatch log group exists: !LOG_GROUP! ...
aws logs create-log-group --log-group-name "!LOG_GROUP!" --region "!AWS_REGION!" >nul 2>&1
echo Log group ready.

REM ---- Check/create ECS cluster ----
echo.
echo Checking ECS cluster: !CLUSTER_NAME! ...
for /f "tokens=*" %%i in ('aws ecs describe-clusters --clusters "!CLUSTER_NAME!" --region "!AWS_REGION!" --query "clusters[0].status" --output text 2^>^&1') do set "CLUSTER_STATUS=%%i"
if not "!CLUSTER_STATUS!"=="ACTIVE" (
    echo Creating ECS cluster: !CLUSTER_NAME! ...
    aws ecs create-cluster --cluster-name "!CLUSTER_NAME!" --region "!AWS_REGION!"
    echo Cluster created.
) else (
    echo Cluster already exists and is ACTIVE.
)

REM ---- Load balancer prompt ----
echo.
set /p "NEED_LB=Do you need an Application Load Balancer for this service? (y/n) [n]: "
if "!NEED_LB!"=="" set "NEED_LB=n"

set "TARGET_GROUP_ARN="
set "ALB_DNS="

if /i "!NEED_LB!"=="y" (
    echo.
    echo Creating Application Load Balancer...
    set /p "ALB_NAME_INPUT=Enter a name for the ALB [cargo-tracker-alb]: "
    if "!ALB_NAME_INPUT!"=="" set "ALB_NAME_INPUT=cargo-tracker-alb"

    for /f "tokens=*" %%i in ('aws elbv2 create-load-balancer --name "!ALB_NAME_INPUT!" --subnets !SUBNET_1! !SUBNET_2! --security-groups "!SECURITY_GROUP!" --scheme internet-facing --type application --ip-address-type ipv4 --region "!AWS_REGION!" --query "LoadBalancers[0].LoadBalancerArn" --output text 2^>^&1') do set "ALB_ARN=%%i"
    echo ALB created: !ALB_ARN!

    for /f "tokens=*" %%i in ('aws elbv2 describe-load-balancers --load-balancer-arns "!ALB_ARN!" --region "!AWS_REGION!" --query "LoadBalancers[0].DNSName" --output text 2^>^&1') do set "ALB_DNS=%%i"

    echo Creating Target Group...
    for /f "tokens=*" %%i in ('aws elbv2 create-target-group --name "cargo-tracker-tg" --protocol HTTP --port 8080 --vpc-id "!VPC_ID!" --target-type ip --health-check-protocol HTTP --health-check-path "/" --health-check-interval-seconds 30 --health-check-timeout-seconds 10 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --region "!AWS_REGION!" --query "TargetGroups[0].TargetGroupArn" --output text 2^>^&1') do set "TARGET_GROUP_ARN=%%i"
    echo Target Group created: !TARGET_GROUP_ARN!

    echo Creating ALB Listener on port 80...
    aws elbv2 create-listener --load-balancer-arn "!ALB_ARN!" --protocol HTTP --port 80 --default-actions "Type=forward,TargetGroupArn=!TARGET_GROUP_ARN!" --region "!AWS_REGION!" >nul
    echo ALB Listener created.
)

REM ---- Prepare task definition ----
echo.
echo Preparing task definition...
set "TASK_DEF_FILE=%TEMP%\task-def-%RANDOM%.json"
copy /y "%~dp0..\ecs\task-definition.json" "!TASK_DEF_FILE!" >nul

powershell -Command "(Get-Content '!TASK_DEF_FILE!') -replace '{{IMAGE_URI}}', '!IMAGE_URI!' -replace '{{AWS_REGION}}', '!AWS_REGION!' -replace '{{ACCOUNT_ID}}', '!ACCOUNT_ID!' | Set-Content '!TASK_DEF_FILE!'"

REM ---- Register task definition ----
echo Registering ECS task definition...
for /f "tokens=*" %%i in ('aws ecs register-task-definition --cli-input-json "file://!TASK_DEF_FILE!" --region "!AWS_REGION!" --query "taskDefinition.taskDefinitionArn" --output text 2^>^&1') do set "TASK_DEF_ARN=%%i"
echo Task definition registered: !TASK_DEF_ARN!
del /f /q "!TASK_DEF_FILE!" >nul 2>&1

REM ---- Prepare service definition ----
echo.
echo Preparing service definition...
set "SERVICE_DEF_FILE=%TEMP%\service-def-%RANDOM%.json"
copy /y "%~dp0..\ecs\service-definition.json" "!SERVICE_DEF_FILE!" >nul

powershell -Command "(Get-Content '!SERVICE_DEF_FILE!') -replace '{{CLUSTER_NAME}}', '!CLUSTER_NAME!' -replace '{{SUBNET_1}}', '!SUBNET_1!' -replace '{{SUBNET_2}}', '!SUBNET_2!' -replace '{{SECURITY_GROUP}}', '!SECURITY_GROUP!' | Set-Content '!SERVICE_DEF_FILE!'"

REM ---- Check if service exists ----
echo.
echo Checking if ECS service exists: !SERVICE_NAME! ...
for /f "tokens=*" %%i in ('aws ecs describe-services --cluster "!CLUSTER_NAME!" --services "!SERVICE_NAME!" --region "!AWS_REGION!" --query "services[?status!='INACTIVE'].serviceName" --output text 2^>^&1') do set "EXISTING_SERVICE=%%i"

if "!EXISTING_SERVICE!"=="" (
    echo Creating new ECS service: !SERVICE_NAME! ...
    aws ecs create-service --cli-input-json "file://!SERVICE_DEF_FILE!" --region "!AWS_REGION!"
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECS service.
        del /f /q "!SERVICE_DEF_FILE!" >nul 2>&1
        exit /b 1
    )
    echo Service created.
) else (
    echo Updating existing ECS service: !SERVICE_NAME! ...
    aws ecs update-service --cluster "!CLUSTER_NAME!" --service "!SERVICE_NAME!" --task-definition "!TASK_DEF_ARN!" --region "!AWS_REGION!" >nul
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to update ECS service.
        del /f /q "!SERVICE_DEF_FILE!" >nul 2>&1
        exit /b 1
    )
    echo Service updated.
)

del /f /q "!SERVICE_DEF_FILE!" >nul 2>&1

REM ---- Wait for stability ----
echo.
echo Waiting for service to stabilize (this may take several minutes)...
aws ecs wait services-stable --cluster "!CLUSTER_NAME!" --services "!SERVICE_NAME!" --region "!AWS_REGION!"
if !ERRORLEVEL! neq 0 (
    echo WARNING: Service did not stabilize within the expected time. Check ECS console.
) else (
    echo Service is stable.
)

REM ---- Verify deployment ----
echo.
echo ==============================================
echo   Deployment Verification
echo ==============================================
aws ecs describe-services --cluster "!CLUSTER_NAME!" --services "!SERVICE_NAME!" --region "!AWS_REGION!" --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}" --output table

echo.
echo CloudWatch Log Group: !LOG_GROUP!
echo   View logs: aws logs tail !LOG_GROUP! --follow --region !AWS_REGION!

if not "!ALB_DNS!"=="" (
    echo.
    echo Application Load Balancer DNS: http://!ALB_DNS!
    echo   (DNS propagation may take a few minutes)
)

echo.
echo ==============================================
echo   Deployment Complete!
echo ==============================================
echo.
echo Troubleshooting tips:
echo   - Check task logs: aws logs tail !LOG_GROUP! --follow --region !AWS_REGION!
echo   - List tasks: aws ecs list-tasks --cluster !CLUSTER_NAME! --service-name !SERVICE_NAME! --region !AWS_REGION!
echo   - Ensure security group allows inbound TCP on port 8080
echo   - Payara startup can take 60-90 seconds; check logs if tasks are stopping

endlocal

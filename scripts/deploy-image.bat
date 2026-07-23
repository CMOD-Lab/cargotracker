@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: Deploy to AWS ECS Fargate - Cargo Tracker (Windows)
:: Jakarta EE application on Payara Server
:: =============================================================================

set "PROJECT_NAME=cargo-tracker"
set "SERVICE_NAME=cargo-tracker-service"
set "TASK_FAMILY=cargo-tracker-task"
set "LOG_GROUP=/ecs/cargo-tracker"
set "TASK_DEF_FILE=ecs\task-definition.json"
set "SERVICE_DEF_FILE=ecs\service-definition.json"

echo ==============================================
echo   Cargo Tracker - AWS ECS Fargate Deployment
echo ==============================================
echo.

:: -----------------------------------------------
:: Collect deployment parameters
:: -----------------------------------------------
set /p "AWS_REGION=Enter AWS Region (e.g., us-east-1): "
set /p "CLUSTER_INPUT=Enter ECS Cluster name [default: cargo-tracker-cluster]: "
if "!CLUSTER_INPUT!"=="" (
    set "CLUSTER_NAME=cargo-tracker-cluster"
) else (
    set "CLUSTER_NAME=!CLUSTER_INPUT!"
)

set /p "IMAGE_URI=Enter ECR Image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/cargo-tracker:latest): "
set /p "VPC_ID=Enter VPC ID (e.g., vpc-xxxxxxxx): "
set /p "SUBNETS_INPUT=Enter Subnet IDs (comma-separated, e.g., subnet-aaa,subnet-bbb): "
set /p "SECURITY_GROUP=Enter Security Group ID (e.g., sg-xxxxxxxx): "

:: Parse subnets
for /f "tokens=1,2 delims=," %%a in ("!SUBNETS_INPUT!") do (
    set "SUBNET_1=%%a"
    set "SUBNET_2=%%b"
)
set "SUBNET_1=!SUBNET_1: =!"
set "SUBNET_2=!SUBNET_2: =!"
if "!SUBNET_2!"=="" set "SUBNET_2=!SUBNET_1!"

:: -----------------------------------------------
:: Get AWS Account ID
:: -----------------------------------------------
echo.
echo Retrieving AWS Account ID...
for /f "delims=" %%i in ('aws sts get-caller-identity --query Account --output text') do set "ACCOUNT_ID=%%i"
echo AWS Account ID: !ACCOUNT_ID!

:: -----------------------------------------------
:: Ensure CloudWatch Log Group exists
:: -----------------------------------------------
echo.
echo Ensuring CloudWatch log group '!LOG_GROUP!' exists...
aws logs create-log-group --log-group-name "!LOG_GROUP!" --region "!AWS_REGION!" >nul 2>&1
echo Log group ready: !LOG_GROUP!

:: -----------------------------------------------
:: Check / Create ECS Cluster
:: -----------------------------------------------
echo.
echo Checking ECS cluster '!CLUSTER_NAME!'...
for /f "delims=" %%s in ('aws ecs describe-clusters --clusters "!CLUSTER_NAME!" --region "!AWS_REGION!" --query "clusters[0].status" --output text 2^>nul') do set "CLUSTER_STATUS=%%s"

if not "!CLUSTER_STATUS!"=="ACTIVE" (
    echo Cluster not found or inactive. Creating cluster '!CLUSTER_NAME!'...
    aws ecs create-cluster --cluster-name "!CLUSTER_NAME!" --region "!AWS_REGION!"
    echo Cluster created: !CLUSTER_NAME!
) else (
    echo Cluster '!CLUSTER_NAME!' is ACTIVE.
)

:: -----------------------------------------------
:: Load Balancer (optional)
:: -----------------------------------------------
echo.
set /p "NEED_LB=Do you need an Application Load Balancer for this service? (y/n): "
set "USE_LB=false"
set "TARGET_GROUP_ARN="
set "ALB_DNS="

if /i "!NEED_LB!"=="y" (
    set "USE_LB=true"
    set "ALB_NAME=cargo-tracker-alb"
    set "TG_NAME=cargo-tracker-tg"

    echo.
    echo Creating Application Load Balancer '!ALB_NAME!'...
    for /f "delims=" %%a in ('aws elbv2 create-load-balancer --name "!ALB_NAME!" --subnets "!SUBNET_1!" "!SUBNET_2!" --security-groups "!SECURITY_GROUP!" --scheme internet-facing --type application --region "!AWS_REGION!" --query "LoadBalancers[0].LoadBalancerArn" --output text') do set "ALB_ARN=%%a"
    echo ALB ARN: !ALB_ARN!

    for /f "delims=" %%d in ('aws elbv2 describe-load-balancers --load-balancer-arns "!ALB_ARN!" --region "!AWS_REGION!" --query "LoadBalancers[0].DNSName" --output text') do set "ALB_DNS=%%d"

    echo Creating Target Group '!TG_NAME!'...
    for /f "delims=" %%t in ('aws elbv2 create-target-group --name "!TG_NAME!" --protocol HTTP --port 8080 --vpc-id "!VPC_ID!" --target-type ip --health-check-path "/cargo-tracker/" --health-check-interval-seconds 60 --health-check-timeout-seconds 30 --healthy-threshold-count 2 --unhealthy-threshold-count 5 --region "!AWS_REGION!" --query "TargetGroups[0].TargetGroupArn" --output text') do set "TARGET_GROUP_ARN=%%t"
    echo Target Group ARN: !TARGET_GROUP_ARN!

    echo Creating ALB Listener on port 80...
    aws elbv2 create-listener --load-balancer-arn "!ALB_ARN!" --protocol HTTP --port 80 --default-actions "Type=forward,TargetGroupArn=!TARGET_GROUP_ARN!" --region "!AWS_REGION!" >nul
    echo ALB Listener created.
)

:: -----------------------------------------------
:: Prepare task definition JSON (replace placeholders)
:: -----------------------------------------------
echo.
echo Preparing task definition...
copy /Y "!TASK_DEF_FILE!" "%TEMP%\task-definition-deploy.json" >nul

powershell -Command "(Get-Content '%TEMP%\task-definition-deploy.json') -replace '{{IMAGE_URI}}','!IMAGE_URI!' -replace '{{AWS_REGION}}','!AWS_REGION!' -replace '{{ACCOUNT_ID}}','!ACCOUNT_ID!' | Set-Content '%TEMP%\task-definition-deploy.json'"

:: -----------------------------------------------
:: Register Task Definition
:: -----------------------------------------------
echo Registering ECS task definition...
for /f "delims=" %%a in ('aws ecs register-task-definition --cli-input-json file://%TEMP%\task-definition-deploy.json --region "!AWS_REGION!" --query "taskDefinition.taskDefinitionArn" --output text') do set "TASK_DEF_ARN=%%a"
echo Task Definition ARN: !TASK_DEF_ARN!

:: -----------------------------------------------
:: Prepare service definition JSON (replace placeholders)
:: -----------------------------------------------
echo.
echo Preparing service definition...
copy /Y "!SERVICE_DEF_FILE!" "%TEMP%\service-definition-deploy.json" >nul

powershell -Command "(Get-Content '%TEMP%\service-definition-deploy.json') -replace '{{CLUSTER_NAME}}','!CLUSTER_NAME!' -replace '{{SUBNET_1}}','!SUBNET_1!' -replace '{{SUBNET_2}}','!SUBNET_2!' -replace '{{SECURITY_GROUP}}','!SECURITY_GROUP!' | Set-Content '%TEMP%\service-definition-deploy.json'"

:: Handle load balancer and task definition ARN injection via PowerShell
if "!USE_LB!"=="true" (
    powershell -Command "$svc = Get-Content '%TEMP%\service-definition-deploy.json' | ConvertFrom-Json; $svc.taskDefinition = '!TASK_DEF_ARN!'; $lb = @{targetGroupArn='!TARGET_GROUP_ARN!'; containerName='cargo-tracker'; containerPort=8080}; $svc | Add-Member -NotePropertyName 'loadBalancers' -NotePropertyValue @($lb) -Force; $svc | Add-Member -NotePropertyName 'healthCheckGracePeriodSeconds' -NotePropertyValue 300 -Force; $svc | ConvertTo-Json -Depth 10 | Set-Content '%TEMP%\service-definition-deploy.json'"
) else (
    powershell -Command "$svc = Get-Content '%TEMP%\service-definition-deploy.json' | ConvertFrom-Json; $svc.taskDefinition = '!TASK_DEF_ARN!'; $svc | ConvertTo-Json -Depth 10 | Set-Content '%TEMP%\service-definition-deploy.json'"
)

:: -----------------------------------------------
:: Create or Update ECS Service
:: -----------------------------------------------
echo.
echo Checking if ECS service '!SERVICE_NAME!' exists...
for /f "delims=" %%s in ('aws ecs describe-services --cluster "!CLUSTER_NAME!" --services "!SERVICE_NAME!" --region "!AWS_REGION!" --query "services[?status!='INACTIVE'].serviceName" --output text 2^>nul') do set "EXISTING_SERVICE=%%s"

if "!EXISTING_SERVICE!"=="" (
    echo Service does not exist. Creating ECS service '!SERVICE_NAME!'...
    aws ecs create-service --cli-input-json file://%TEMP%\service-definition-deploy.json --region "!AWS_REGION!"
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create ECS service.
        exit /b 1
    )
    echo ECS service '!SERVICE_NAME!' created.
) else (
    echo Service '!SERVICE_NAME!' exists. Updating service with new task definition...
    aws ecs update-service --cluster "!CLUSTER_NAME!" --service "!SERVICE_NAME!" --task-definition "!TASK_DEF_ARN!" --region "!AWS_REGION!" >nul
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to update ECS service.
        exit /b 1
    )
    echo ECS service updated.
)

:: -----------------------------------------------
:: Wait for service stability
:: -----------------------------------------------
echo.
echo Waiting for ECS service to stabilize (this may take several minutes)...
aws ecs wait services-stable --cluster "!CLUSTER_NAME!" --services "!SERVICE_NAME!" --region "!AWS_REGION!"
if !ERRORLEVEL! neq 0 (
    echo WARNING: Service may not have stabilized within the timeout period.
) else (
    echo Service is stable!
)

:: -----------------------------------------------
:: Verify deployment
:: -----------------------------------------------
echo.
echo ==============================================
echo   Deployment Verification
echo ==============================================
aws ecs describe-services --cluster "!CLUSTER_NAME!" --services "!SERVICE_NAME!" --region "!AWS_REGION!" --query "services[0].{ServiceName:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}" --output table

echo.
echo ==============================================
echo   Deployment Complete!
echo ==============================================
echo Cluster        : !CLUSTER_NAME!
echo Service        : !SERVICE_NAME!
echo Task Def ARN   : !TASK_DEF_ARN!
echo CloudWatch Logs: !LOG_GROUP!
if "!USE_LB!"=="true" (
    if not "!ALB_DNS!"=="" (
        echo Load Balancer  : http://!ALB_DNS!/cargo-tracker/
    )
)
echo.
echo Troubleshooting tips:
echo   - View logs: aws logs tail !LOG_GROUP! --follow --region !AWS_REGION!
echo   - List tasks: aws ecs list-tasks --cluster !CLUSTER_NAME! --service-name !SERVICE_NAME! --region !AWS_REGION!
echo.

endlocal

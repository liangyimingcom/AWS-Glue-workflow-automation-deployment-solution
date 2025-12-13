#!/bin/bash

# AWS Glue HelloWorld 一键部署脚本
# 使用方法: ./deploy-glue-stack.sh [环境] [AWS配置文件] [区域]

set -e

# 默认参数
ENVIRONMENT=${1:-dev}
AWS_PROFILE=${2:-default}
AWS_REGION=${3:-us-east-1}
STACK_NAME="glue-helloworld-${ENVIRONMENT}"
TEMPLATE_FILE="glue-helloworld-cloudformation.yaml"

echo "🚀 开始部署 AWS Glue HelloWorld 工作流"
echo "📋 部署参数:"
echo "   环境: $ENVIRONMENT"
echo "   AWS配置文件: $AWS_PROFILE"
echo "   区域: $AWS_REGION"
echo "   堆栈名称: $STACK_NAME"
echo ""

# 检查模板文件是否存在
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ 错误: 找不到CloudFormation模板文件 $TEMPLATE_FILE"
    exit 1
fi

# 验证模板
echo "🔍 验证CloudFormation模板..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --profile $AWS_PROFILE \
    --region $AWS_REGION

if [ $? -eq 0 ]; then
    echo "✅ 模板验证通过"
else
    echo "❌ 模板验证失败"
    exit 1
fi

# 部署堆栈
echo ""
echo "🚀 开始部署CloudFormation堆栈..."
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --parameter-overrides Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --profile $AWS_PROFILE \
    --region $AWS_REGION

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 部署成功完成!"
    echo ""
    
    # 获取输出信息
    echo "📊 堆栈输出信息:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table \
        --profile $AWS_PROFILE \
        --region $AWS_REGION
    
    echo ""
    echo "🎯 后续操作:"
    echo "1. 启动工作流:"
    WORKFLOW_NAME=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[?OutputKey==`WorkflowName`].OutputValue' \
        --output text \
        --profile $AWS_PROFILE \
        --region $AWS_REGION)
    
    echo "   aws glue start-workflow-run --name $WORKFLOW_NAME --profile $AWS_PROFILE --region $AWS_REGION"
    echo ""
    echo "2. 查看工作流状态:"
    echo "   aws glue get-workflow --name $WORKFLOW_NAME --profile $AWS_PROFILE --region $AWS_REGION"
    echo ""
    echo "3. 删除堆栈:"
    echo "   aws cloudformation delete-stack --stack-name $STACK_NAME --profile $AWS_PROFILE --region $AWS_REGION"
    
else
    echo "❌ 部署失败"
    exit 1
fi

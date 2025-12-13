#!/bin/bash

# AWS Glue资源导出脚本 (AWS原生方案)
# 使用方法: ./export-glue-to-cloudformation.sh [工作流名称] [AWS配置文件] [区域]

set -e

# 参数
WORKFLOW_NAME=${1:-helloworld}
AWS_PROFILE=${2:-oversea1}
AWS_REGION=${3:-us-east-1}
OUTPUT_DIR="./cloudformation-export"

echo "🔍 AWS Glue资源导出工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 导出参数:"
echo "   工作流名称: $WORKFLOW_NAME"
echo "   AWS配置文件: $AWS_PROFILE"
echo "   区域: $AWS_REGION"
echo "   输出目录: $OUTPUT_DIR"
echo ""

# 创建输出目录
mkdir -p $OUTPUT_DIR

# 导出工作流
echo "📦 导出Glue工作流..."
aws glue get-workflow \
  --name $WORKFLOW_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --output json > $OUTPUT_DIR/workflow.json

if [ $? -eq 0 ]; then
    echo "   ✅ 工作流导出成功"
else
    echo "   ❌ 工作流导出失败"
    exit 1
fi

# 列出所有作业并查找匹配的
echo "📦 导出Glue作业..."
JOB_NAME=$(aws glue list-jobs \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --query "JobNames[?contains(@, '$WORKFLOW_NAME')]" \
  --output text | head -1)

if [ -z "$JOB_NAME" ]; then
    JOB_NAME="${WORKFLOW_NAME}-job"
fi

aws glue get-job \
  --job-name $JOB_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --output json > $OUTPUT_DIR/job.json

if [ $? -eq 0 ]; then
    echo "   ✅ 作业导出成功: $JOB_NAME"
else
    echo "   ❌ 作业导出失败: $JOB_NAME"
    exit 1
fi

# 获取触发器名称
TRIGGER_NAME=$(aws glue list-triggers \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --query "TriggerNames[?contains(@, '$WORKFLOW_NAME')]" \
  --output text | head -1)

if [ -z "$TRIGGER_NAME" ]; then
    TRIGGER_NAME="${WORKFLOW_NAME}-trigger"
fi

# 导出触发器
echo "📦 导出Glue触发器..."
aws glue get-trigger \
  --name $TRIGGER_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --output json > $OUTPUT_DIR/trigger.json

if [ $? -eq 0 ]; then
    echo "   ✅ 触发器导出成功: $TRIGGER_NAME"
else
    echo "   ⚠️  触发器导出失败"
fi

# 导出S3脚本
echo "📦 导出Glue脚本..."
SCRIPT_LOCATION=$(cat $OUTPUT_DIR/job.json | grep -o 's3://[^"]*' | head -1)

if [ ! -z "$SCRIPT_LOCATION" ]; then
    echo "   脚本位置: $SCRIPT_LOCATION"
    aws s3 cp $SCRIPT_LOCATION $OUTPUT_DIR/helloworld_job.py \
      --profile $AWS_PROFILE \
      --region $AWS_REGION
    
    if [ $? -eq 0 ]; then
        echo "   ✅ 脚本下载成功"
    else
        echo "   ⚠️  脚本下载失败"
    fi
fi

# 生成资源摘要
echo ""
echo "📊 生成资源摘要..."
cat > $OUTPUT_DIR/resource-summary.txt << EOF
AWS Glue资源导出摘要
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
导出时间: $(date)
工作流名称: $WORKFLOW_NAME
AWS账号: $(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
区域: $AWS_REGION

导出的资源:
- 工作流: $WORKFLOW_NAME
- 作业: $JOB_NAME
- 触发器: $TRIGGER_NAME
- 脚本: $SCRIPT_LOCATION

导出文件:
- workflow.json
- job.json
- trigger.json
- helloworld_job.py
- resource-summary.txt

下一步操作:
1. 查看导出的JSON文件
2. 使用CloudFormation模板部署到目标账号
3. 运行: ./deploy-glue-stack.sh [环境] [目标配置文件] [区域]
EOF

echo "✅ 导出完成！"
echo ""
echo "📁 导出文件位置: $OUTPUT_DIR"
echo "📄 资源摘要: $OUTPUT_DIR/resource-summary.txt"
echo ""

# 自动生成CloudFormation模板
if [ -f "./generate-cloudformation-from-export.sh" ]; then
    echo "🔨 自动生成CloudFormation模板..."
    ./generate-cloudformation-from-export.sh
else
    echo "⚠️  提示: 运行 ./generate-cloudformation-from-export.sh 生成CloudFormation模板"
fi

echo ""
echo "🚀 下一步操作:"
echo "   1. 查看生成的模板: cat $OUTPUT_DIR/generated-cloudformation.yaml"
echo "   2. 验证模板: aws cloudformation validate-template --template-body file://$OUTPUT_DIR/generated-cloudformation.yaml"
echo "   3. 部署到目标账号: aws cloudformation deploy --template-file $OUTPUT_DIR/generated-cloudformation.yaml --stack-name glue-stack --capabilities CAPABILITY_IAM"

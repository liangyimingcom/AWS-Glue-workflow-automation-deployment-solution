#!/bin/bash

# 从导出的JSON生成CloudFormation模板
# 使用方法: ./generate-cloudformation-from-export.sh

set -e

EXPORT_DIR="./cloudformation-export"
OUTPUT_FILE="./cloudformation-export/generated-cloudformation.yaml"

echo "🔧 CloudFormation模板生成工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查导出目录
if [ ! -d "$EXPORT_DIR" ]; then
    echo "❌ 错误: 找不到导出目录 $EXPORT_DIR"
    echo "请先运行: ./export-glue-to-cloudformation.sh"
    exit 1
fi

# 检查必要文件
for file in workflow.json job.json trigger.json; do
    if [ ! -f "$EXPORT_DIR/$file" ]; then
        echo "❌ 错误: 找不到 $file"
        exit 1
    fi
done

echo "📦 读取导出的配置文件..."

# 提取配置信息
WORKFLOW_NAME=$(cat $EXPORT_DIR/workflow.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
WORKFLOW_DESC=$(cat $EXPORT_DIR/workflow.json | grep -o '"Description": "[^"]*"' | head -1 | cut -d'"' -f4)

JOB_NAME=$(cat $EXPORT_DIR/job.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
JOB_ROLE=$(cat $EXPORT_DIR/job.json | grep -o '"Role": "[^"]*"' | head -1 | cut -d'"' -f4)
SCRIPT_LOCATION=$(cat $EXPORT_DIR/job.json | grep -o 's3://[^"]*' | head -1)
GLUE_VERSION=$(cat $EXPORT_DIR/job.json | grep -o '"GlueVersion": "[^"]*"' | head -1 | cut -d'"' -f4)
WORKER_TYPE=$(cat $EXPORT_DIR/job.json | grep -o '"WorkerType": "[^"]*"' | head -1 | cut -d'"' -f4)
NUM_WORKERS=$(cat $EXPORT_DIR/job.json | grep -o '"NumberOfWorkers": [0-9]*' | head -1 | awk '{print $2}')

TRIGGER_NAME=$(cat $EXPORT_DIR/trigger.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
TRIGGER_TYPE=$(cat $EXPORT_DIR/trigger.json | grep -o '"Type": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "   ✅ 工作流: $WORKFLOW_NAME"
echo "   ✅ 作业: $JOB_NAME"
echo "   ✅ 触发器: $TRIGGER_NAME"

# 生成CloudFormation模板
echo ""
echo "🔨 生成CloudFormation模板..."

cat > $OUTPUT_FILE << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Glue Workflow - 从现有资源自动生成'

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues: [dev, test, prod]
    Description: 部署环境
  
  ProjectName:
    Type: String
    Default: WORKFLOW_NAME_PLACEHOLDER
    Description: 项目名称

Resources:
  # Glue工作流
  GlueWorkflow:
    Type: AWS::Glue::Workflow
    Properties:
      Name: !Sub "${ProjectName}-${Environment}"
      Description: WORKFLOW_DESC_PLACEHOLDER

  # Glue作业
  GlueJob:
    Type: AWS::Glue::Job
    Properties:
      Name: !Sub "${ProjectName}-job-${Environment}"
      Role: JOB_ROLE_PLACEHOLDER
      Command:
        Name: glueetl
        ScriptLocation: SCRIPT_LOCATION_PLACEHOLDER
        PythonVersion: "3"
      DefaultArguments:
        "--JOB_NAME": !Sub "${ProjectName}-job-${Environment}"
        "--enable-metrics": ""
        "--enable-continuous-cloudwatch-log": "true"
      ExecutionProperty:
        MaxConcurrentRuns: 1
      MaxRetries: 0
      Timeout: 2880
      GlueVersion: "GLUE_VERSION_PLACEHOLDER"
      WorkerType: WORKER_TYPE_PLACEHOLDER
      NumberOfWorkers: NUM_WORKERS_PLACEHOLDER

  # Glue触发器
  GlueTrigger:
    Type: AWS::Glue::Trigger
    Properties:
      Name: !Sub "${ProjectName}-trigger-${Environment}"
      Type: TRIGGER_TYPE_PLACEHOLDER
      WorkflowName: !Ref GlueWorkflow
      Actions:
        - JobName: !Ref GlueJob

Outputs:
  WorkflowName:
    Description: Glue工作流名称
    Value: !Ref GlueWorkflow
    Export:
      Name: !Sub "${AWS::StackName}-WorkflowName"
  
  JobName:
    Description: Glue作业名称
    Value: !Ref GlueJob
    Export:
      Name: !Sub "${AWS::StackName}-JobName"
  
  TriggerName:
    Description: Glue触发器名称
    Value: !Ref GlueTrigger
    Export:
      Name: !Sub "${AWS::StackName}-TriggerName"
EOF

# 替换占位符
sed -i '' "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
sed -i '' "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
sed -i '' "s|JOB_ROLE_PLACEHOLDER|$JOB_ROLE|g" $OUTPUT_FILE
sed -i '' "s|SCRIPT_LOCATION_PLACEHOLDER|$SCRIPT_LOCATION|g" $OUTPUT_FILE
sed -i '' "s|GLUE_VERSION_PLACEHOLDER|$GLUE_VERSION|g" $OUTPUT_FILE
sed -i '' "s|WORKER_TYPE_PLACEHOLDER|$WORKER_TYPE|g" $OUTPUT_FILE
sed -i '' "s|NUM_WORKERS_PLACEHOLDER|$NUM_WORKERS|g" $OUTPUT_FILE
sed -i '' "s|TRIGGER_TYPE_PLACEHOLDER|$TRIGGER_TYPE|g" $OUTPUT_FILE

echo "✅ CloudFormation模板生成完成！"
echo ""
echo "📁 输出文件: $OUTPUT_FILE"
echo ""
echo "🔍 验证模板:"
echo "   aws cloudformation validate-template --template-body file://$OUTPUT_FILE"
echo ""
echo "🚀 部署模板:"
echo "   aws cloudformation deploy --template-file $OUTPUT_FILE --stack-name glue-workflow-stack --capabilities CAPABILITY_IAM"

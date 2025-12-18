#!/bin/bash

# 简单项目 CloudFormation 模板生成器
# 适用于: 1-5 个资源的简单 Glue 工作流
# 使用方法: ./generate-simple-cloudformation.sh [导出目录] [项目名称]

set -e

EXPORT_DIR=${1:-"./cloudformation-export"}
PROJECT_NAME=${2:-"helloworld"}
OUTPUT_FILE="$EXPORT_DIR/cloudformation.yaml"

echo "🔨 生成简单项目 CloudFormation 模板..."

# 检查必要文件
if [ ! -f "$EXPORT_DIR/workflow.json" ] || [ ! -f "$EXPORT_DIR/job.json" ]; then
    echo "❌ 错误: 缺少必要的配置文件"
    exit 1
fi

# 提取配置信息
WORKFLOW_NAME=$(cat $EXPORT_DIR/workflow.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
WORKFLOW_DESC=$(cat $EXPORT_DIR/workflow.json | grep -o '"Description": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "Glue 工作流")

JOB_NAME=$(cat $EXPORT_DIR/job.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
JOB_ROLE=$(cat $EXPORT_DIR/job.json | grep -o '"Role": "[^"]*"' | head -1 | cut -d'"' -f4)
SCRIPT_LOCATION=$(cat $EXPORT_DIR/job.json | grep -o 's3://[^"]*' | head -1)
GLUE_VERSION=$(cat $EXPORT_DIR/job.json | grep -o '"GlueVersion": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "4.0")
WORKER_TYPE=$(cat $EXPORT_DIR/job.json | grep -o '"WorkerType": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "G.1X")
NUM_WORKERS=$(cat $EXPORT_DIR/job.json | grep -o '"NumberOfWorkers": [0-9]*' | head -1 | awk '{print $2}' || echo "2")

TRIGGER_NAME=$(cat $EXPORT_DIR/trigger.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "${WORKFLOW_NAME}-trigger")
TRIGGER_TYPE=$(cat $EXPORT_DIR/trigger.json | grep -o '"Type": "[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "ON_DEMAND")

# 生成简单模板
cat > $OUTPUT_FILE << 'EOFTEMPLATE'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Glue 工作流 - 简单项目自动生成'

Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: "项目配置"
        Parameters:
          - ProjectName
          - Environment
    ParameterLabels:
      ProjectName:
        default: "项目名称"
      Environment:
        default: "部署环境"

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - test
      - prod
    Description: 部署环境（开发/测试/生产）
  
  ProjectName:
    Type: String
    Default: WORKFLOW_NAME_PLACEHOLDER
    Description: 项目名称，用于资源命名
    AllowedPattern: '^[a-z][a-z0-9-]*$'
    ConstraintDescription: 必须以小写字母开头，只能包含小写字母、数字和连字符

Resources:
  # ===========================================
  # Glue 工作流
  # ===========================================
  GlueWorkflow:
    Type: AWS::Glue::Workflow
    Properties:
      Name: !Sub '${ProjectName}-${Environment}'
      Description: WORKFLOW_DESC_PLACEHOLDER
      Tags:
        Name: !Sub '${ProjectName}-${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName
        ManagedBy: CloudFormation

  # ===========================================
  # Glue 作业
  # ===========================================
  GlueJob:
    Type: AWS::Glue::Job
    Properties:
      Name: !Sub '${ProjectName}-job-${Environment}'
      Role: JOB_ROLE_PLACEHOLDER
      Command:
        Name: glueetl
        ScriptLocation: SCRIPT_LOCATION_PLACEHOLDER
        PythonVersion: "3"
      DefaultArguments:
        '--job-bookmark-option': 'job-bookmark-enable'
        '--enable-metrics': ''
        '--enable-continuous-cloudwatch-log': 'true'
        '--job-language': 'python'
        '--TempDir': !Sub 's3://aws-glue-temporary-${AWS::AccountId}-${AWS::Region}/temp/'
      ExecutionProperty:
        MaxConcurrentRuns: 1
      MaxRetries: 0
      Timeout: 2880
      GlueVersion: 'GLUE_VERSION_PLACEHOLDER'
      WorkerType: WORKER_TYPE_PLACEHOLDER
      NumberOfWorkers: NUM_WORKERS_PLACEHOLDER
      Tags:
        Name: !Sub '${ProjectName}-job-${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName

  # ===========================================
  # Glue 触发器
  # ===========================================
  GlueTrigger:
    Type: AWS::Glue::Trigger
    Properties:
      Name: !Sub '${ProjectName}-trigger-${Environment}'
      Type: TRIGGER_TYPE_PLACEHOLDER
      WorkflowName: !Ref GlueWorkflow
      Actions:
        - JobName: !Ref GlueJob
      Tags:
        Name: !Sub '${ProjectName}-trigger-${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName

Outputs:
  WorkflowName:
    Description: Glue 工作流名称
    Value: !Ref GlueWorkflow
    Export:
      Name: !Sub '${AWS::StackName}-WorkflowName'
  
  JobName:
    Description: Glue 作业名称
    Value: !Ref GlueJob
    Export:
      Name: !Sub '${AWS::StackName}-JobName'
  
  TriggerName:
    Description: Glue 触发器名称
    Value: !Ref GlueTrigger
    Export:
      Name: !Sub '${AWS::StackName}-TriggerName'
  
  StackInfo:
    Description: CloudFormation 堆栈信息
    Value: !Sub |
      堆栈: ${AWS::StackName}
      区域: ${AWS::Region}
      账号: ${AWS::AccountId}
      环境: ${Environment}
EOFTEMPLATE

# 替换占位符
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
    sed -i '' "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
    sed -i '' "s|JOB_ROLE_PLACEHOLDER|$JOB_ROLE|g" $OUTPUT_FILE
    sed -i '' "s|SCRIPT_LOCATION_PLACEHOLDER|$SCRIPT_LOCATION|g" $OUTPUT_FILE
    sed -i '' "s|GLUE_VERSION_PLACEHOLDER|$GLUE_VERSION|g" $OUTPUT_FILE
    sed -i '' "s|WORKER_TYPE_PLACEHOLDER|$WORKER_TYPE|g" $OUTPUT_FILE
    sed -i '' "s|NUM_WORKERS_PLACEHOLDER|$NUM_WORKERS|g" $OUTPUT_FILE
    sed -i '' "s|TRIGGER_TYPE_PLACEHOLDER|$TRIGGER_TYPE|g" $OUTPUT_FILE
else
    # Linux
    sed -i "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
    sed -i "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
    sed -i "s|JOB_ROLE_PLACEHOLDER|$JOB_ROLE|g" $OUTPUT_FILE
    sed -i "s|SCRIPT_LOCATION_PLACEHOLDER|$SCRIPT_LOCATION|g" $OUTPUT_FILE
    sed -i "s|GLUE_VERSION_PLACEHOLDER|$GLUE_VERSION|g" $OUTPUT_FILE
    sed -i "s|WORKER_TYPE_PLACEHOLDER|$WORKER_TYPE|g" $OUTPUT_FILE
    sed -i "s|NUM_WORKERS_PLACEHOLDER|$NUM_WORKERS|g" $OUTPUT_FILE
    sed -i "s|TRIGGER_TYPE_PLACEHOLDER|$TRIGGER_TYPE|g" $OUTPUT_FILE
fi

echo "✅ 简单项目模板已生成: $OUTPUT_FILE"

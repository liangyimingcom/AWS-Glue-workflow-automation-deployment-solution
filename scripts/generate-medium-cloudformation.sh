#!/bin/bash

# 中等复杂度项目 CloudFormation 模板生成器
# 适用于: 5-15 个资源的 Glue 工作流
# 使用方法: ./generate-medium-cloudformation.sh [导出目录] [项目名称]

set -e

EXPORT_DIR=${1:-"./cloudformation-export"}
PROJECT_NAME=${2:-"helloworld"}
OUTPUT_FILE="$EXPORT_DIR/cloudformation.yaml"

echo "🔨 生成中等复杂度 CloudFormation 模板..."

# 检查必要文件
if [ ! -f "$EXPORT_DIR/workflow.json" ]; then
    echo "❌ 错误: 缺少 workflow.json"
    exit 1
fi

# 提取工作流信息
WORKFLOW_NAME=$(cat $EXPORT_DIR/workflow.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
WORKFLOW_DESC=$(cat $EXPORT_DIR/workflow.json | grep -o '"Description": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "Glue 数据处理工作流")

# 统计作业数量
JOB_COUNT=$(ls $EXPORT_DIR/job-*.json 2>/dev/null | wc -l)
if [ $JOB_COUNT -eq 0 ] && [ -f "$EXPORT_DIR/job.json" ]; then
    JOB_COUNT=1
fi

# 统计触发器数量
TRIGGER_COUNT=$(ls $EXPORT_DIR/trigger-*.json 2>/dev/null | wc -l)
if [ $TRIGGER_COUNT -eq 0 ] && [ -f "$EXPORT_DIR/trigger.json" ]; then
    TRIGGER_COUNT=1
fi

# 统计爬虫数量
CRAWLER_COUNT=$(ls $EXPORT_DIR/crawler-*.json 2>/dev/null | wc -l)

echo "   检测到 $JOB_COUNT 个作业, $TRIGGER_COUNT 个触发器, $CRAWLER_COUNT 个爬虫"

# 生成模板头部
cat > $OUTPUT_FILE << 'EOFHEADER'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Glue 工作流 - 中等复杂度项目自动生成'

Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: "基础配置"
        Parameters:
          - ProjectName
          - Environment
      - Label:
          default: "资源配置"
        Parameters:
          - GlueVersion
          - WorkerType
          - NumberOfWorkers
    ParameterLabels:
      ProjectName:
        default: "项目名称"
      Environment:
        default: "部署环境"
      GlueVersion:
        default: "Glue 版本"
      WorkerType:
        default: "Worker 类型"
      NumberOfWorkers:
        default: "Worker 数量"

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - test
      - prod
    Description: 部署环境
  
  ProjectName:
    Type: String
    Default: WORKFLOW_NAME_PLACEHOLDER
    Description: 项目名称
    AllowedPattern: '^[a-z][a-z0-9-]*$'
    ConstraintDescription: 必须以小写字母开头，只能包含小写字母、数字和连字符
  
  GlueVersion:
    Type: String
    Default: "4.0"
    AllowedValues:
      - "2.0"
      - "3.0"
      - "4.0"
    Description: AWS Glue 版本
  
  WorkerType:
    Type: String
    Default: G.1X
    AllowedValues:
      - Standard
      - G.1X
      - G.2X
      - G.025X
    Description: Worker 类型
  
  NumberOfWorkers:
    Type: Number
    Default: 2
    MinValue: 2
    MaxValue: 100
    Description: Worker 数量

Mappings:
  EnvironmentConfig:
    dev:
      LogLevel: INFO
      MaxRetries: 0
      Timeout: 2880
    test:
      LogLevel: INFO
      MaxRetries: 1
      Timeout: 2880
    prod:
      LogLevel: WARN
      MaxRetries: 2
      Timeout: 4320

Conditions:
  IsProduction: !Equals [!Ref Environment, prod]
  IsDevelopment: !Equals [!Ref Environment, dev]

Resources:
  # ===========================================
  # Glue 工作流
  # ===========================================
  GlueWorkflow:
    Type: AWS::Glue::Workflow
    Properties:
      Name: !Sub '${ProjectName}-${Environment}'
      Description: WORKFLOW_DESC_PLACEHOLDER
      MaxConcurrentRuns: !If [IsProduction, 5, 2]
      Tags:
        Name: !Sub '${ProjectName}-${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName
        ManagedBy: CloudFormation
        CostCenter: DataEngineering

EOFHEADER

# 替换工作流占位符
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
    sed -i '' "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
else
    sed -i "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
    sed -i "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
fi

# 添加所有作业
echo "   添加 Glue 作业定义..."
for i in $(seq 1 $JOB_COUNT); do
    JOB_FILE="$EXPORT_DIR/job-${i}.json"
    if [ ! -f "$JOB_FILE" ]; then
        JOB_FILE="$EXPORT_DIR/job.json"
    fi
    
    if [ -f "$JOB_FILE" ]; then
        JOB_NAME=$(cat $JOB_FILE | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
        JOB_ROLE=$(cat $JOB_FILE | grep -o '"Role": "[^"]*"' | head -1 | cut -d'"' -f4)
        SCRIPT_LOCATION=$(cat $JOB_FILE | grep -o 's3://[^"]*' | head -1)
        
        cat >> $OUTPUT_FILE << EOFJOB
  # ===========================================
  # Glue 作业 $i
  # ===========================================
  GlueJob${i}:
    Type: AWS::Glue::Job
    Properties:
      Name: !Sub '\${ProjectName}-job${i}-\${Environment}'
      Role: $JOB_ROLE
      Command:
        Name: glueetl
        ScriptLocation: $SCRIPT_LOCATION
        PythonVersion: "3"
      DefaultArguments:
        '--job-bookmark-option': 'job-bookmark-enable'
        '--enable-metrics': ''
        '--enable-spark-ui': 'true'
        '--spark-event-logs-path': !Sub 's3://aws-glue-temporary-\${AWS::AccountId}-\${AWS::Region}/sparkui-logs/'
        '--enable-continuous-cloudwatch-log': 'true'
        '--job-language': 'python'
        '--TempDir': !Sub 's3://aws-glue-temporary-\${AWS::AccountId}-\${AWS::Region}/temp/'
        '--enable-glue-datacatalog': ''
      ExecutionProperty:
        MaxConcurrentRuns: !If [IsProduction, 3, 1]
      MaxRetries: !FindInMap [EnvironmentConfig, !Ref Environment, MaxRetries]
      Timeout: !FindInMap [EnvironmentConfig, !Ref Environment, Timeout]
      GlueVersion: !Ref GlueVersion
      WorkerType: !Ref WorkerType
      NumberOfWorkers: !Ref NumberOfWorkers
      Tags:
        Name: !Sub '\${ProjectName}-job${i}-\${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName

EOFJOB
    fi
done

# 添加所有触发器
echo "   添加 Glue 触发器定义..."
for i in $(seq 1 $TRIGGER_COUNT); do
    TRIGGER_FILE="$EXPORT_DIR/trigger-${i}.json"
    if [ ! -f "$TRIGGER_FILE" ]; then
        TRIGGER_FILE="$EXPORT_DIR/trigger.json"
    fi
    
    if [ -f "$TRIGGER_FILE" ]; then
        TRIGGER_NAME=$(cat $TRIGGER_FILE | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "trigger${i}")
        TRIGGER_TYPE=$(cat $TRIGGER_FILE | grep -o '"Type": "[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "ON_DEMAND")
        
        cat >> $OUTPUT_FILE << EOFTRIGGER
  # ===========================================
  # Glue 触发器 $i
  # ===========================================
  GlueTrigger${i}:
    Type: AWS::Glue::Trigger
    Properties:
      Name: !Sub '\${ProjectName}-trigger${i}-\${Environment}'
      Type: $TRIGGER_TYPE
      WorkflowName: !Ref GlueWorkflow
      Actions:
        - JobName: !Ref GlueJob${i}
      Tags:
        Name: !Sub '\${ProjectName}-trigger${i}-\${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName

EOFTRIGGER
    fi
done

# 添加爬虫（如果存在）
if [ $CRAWLER_COUNT -gt 0 ]; then
    echo "   添加 Glue 爬虫定义..."
    for i in $(seq 1 $CRAWLER_COUNT); do
        CRAWLER_FILE="$EXPORT_DIR/crawler-${i}.json"
        if [ -f "$CRAWLER_FILE" ]; then
            CRAWLER_NAME=$(cat $CRAWLER_FILE | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
            CRAWLER_ROLE=$(cat $CRAWLER_FILE | grep -o '"Role": "[^"]*"' | head -1 | cut -d'"' -f4)
            DATABASE_NAME=$(cat $CRAWLER_FILE | grep -o '"DatabaseName": "[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "default")
            
            cat >> $OUTPUT_FILE << EOFCRAWLER
  # ===========================================
  # Glue 爬虫 $i
  # ===========================================
  GlueCrawler${i}:
    Type: AWS::Glue::Crawler
    Properties:
      Name: !Sub '\${ProjectName}-crawler${i}-\${Environment}'
      Role: $CRAWLER_ROLE
      DatabaseName: $DATABASE_NAME
      Targets:
        S3Targets:
          - Path: !Sub 's3://\${ProjectName}-data-\${Environment}/'
      SchemaChangePolicy:
        UpdateBehavior: UPDATE_IN_DATABASE
        DeleteBehavior: LOG
      Tags:
        Name: !Sub '\${ProjectName}-crawler${i}-\${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName

EOFCRAWLER
        fi
    done
fi

# 添加输出部分
cat >> $OUTPUT_FILE << 'EOFOUTPUT'

Outputs:
  WorkflowName:
    Description: Glue 工作流名称
    Value: !Ref GlueWorkflow
    Export:
      Name: !Sub '${AWS::StackName}-WorkflowName'
  
  WorkflowArn:
    Description: Glue 工作流 ARN
    Value: !Sub 'arn:aws:glue:${AWS::Region}:${AWS::AccountId}:workflow/${GlueWorkflow}'
    Export:
      Name: !Sub '${AWS::StackName}-WorkflowArn'
EOFOUTPUT

# 添加作业输出
for i in $(seq 1 $JOB_COUNT); do
    cat >> $OUTPUT_FILE << EOFJOBOUTPUT
  
  Job${i}Name:
    Description: Glue 作业 $i 名称
    Value: !Ref GlueJob${i}
    Export:
      Name: !Sub '\${AWS::StackName}-Job${i}Name'
EOFJOBOUTPUT
done

# 添加触发器输出
for i in $(seq 1 $TRIGGER_COUNT); do
    cat >> $OUTPUT_FILE << EOFTRIGGEROUTPUT
  
  Trigger${i}Name:
    Description: Glue 触发器 $i 名称
    Value: !Ref GlueTrigger${i}
    Export:
      Name: !Sub '\${AWS::StackName}-Trigger${i}Name'
EOFTRIGGEROUTPUT
done

# 添加堆栈信息输出
cat >> $OUTPUT_FILE << 'EOFSTACKINFO'
  
  StackInfo:
    Description: CloudFormation 堆栈信息
    Value: !Sub |
      堆栈名称: ${AWS::StackName}
      区域: ${AWS::Region}
      账号: ${AWS::AccountId}
      环境: ${Environment}
      项目: ${ProjectName}
EOFSTACKINFO

echo "✅ 中等复杂度模板已生成: $OUTPUT_FILE"
echo "   包含: $JOB_COUNT 个作业, $TRIGGER_COUNT 个触发器, $CRAWLER_COUNT 个爬虫"

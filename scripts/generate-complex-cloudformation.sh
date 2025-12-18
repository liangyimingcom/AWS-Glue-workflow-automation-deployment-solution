#!/bin/bash

# 复杂项目 CloudFormation 模板生成器
# 适用于: 15+ 个资源的复杂 Glue 工作流
# 使用方法: ./generate-complex-cloudformation.sh [导出目录] [项目名称]

set -e

EXPORT_DIR=${1:-"./cloudformation-export"}
PROJECT_NAME=${2:-"helloworld"}
OUTPUT_FILE="$EXPORT_DIR/cloudformation.yaml"
NESTED_STACK_DIR="$EXPORT_DIR/nested-stacks"

echo "🔨 生成复杂项目 CloudFormation 模板（使用嵌套栈）..."

# 创建嵌套栈目录
mkdir -p $NESTED_STACK_DIR

# 检查必要文件
if [ ! -f "$EXPORT_DIR/workflow.json" ]; then
    echo "❌ 错误: 缺少 workflow.json"
    exit 1
fi

# 提取工作流信息
WORKFLOW_NAME=$(cat $EXPORT_DIR/workflow.json | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
WORKFLOW_DESC=$(cat $EXPORT_DIR/workflow.json | grep -o '"Description": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "Glue 复杂数据处理工作流")

# 统计资源
JOB_COUNT=$(ls $EXPORT_DIR/job-*.json 2>/dev/null | wc -l)
[ $JOB_COUNT -eq 0 ] && [ -f "$EXPORT_DIR/job.json" ] && JOB_COUNT=1

TRIGGER_COUNT=$(ls $EXPORT_DIR/trigger-*.json 2>/dev/null | wc -l)
[ $TRIGGER_COUNT -eq 0 ] && [ -f "$EXPORT_DIR/trigger.json" ] && TRIGGER_COUNT=1

CRAWLER_COUNT=$(ls $EXPORT_DIR/crawler-*.json 2>/dev/null | wc -l)

echo "   检测到 $JOB_COUNT 个作业, $TRIGGER_COUNT 个触发器, $CRAWLER_COUNT 个爬虫"
echo "   使用嵌套栈架构以支持大规模部署"

# ========================================
# 生成主栈模板
# ========================================
cat > $OUTPUT_FILE << 'EOFMASTER'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Glue 工作流 - 复杂项目主栈（使用嵌套栈架构）'

Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: "基础配置"
        Parameters:
          - ProjectName
          - Environment
      - Label:
          default: "网络配置"
        Parameters:
          - VpcId
          - SubnetIds
          - SecurityGroupIds
      - Label:
          default: "资源配置"
        Parameters:
          - GlueVersion
          - WorkerType
          - NumberOfWorkers
      - Label:
          default: "高级配置"
        Parameters:
          - EnableMonitoring
          - LogRetentionDays
          - NestedStacksBucket
    ParameterLabels:
      ProjectName:
        default: "项目名称"
      Environment:
        default: "部署环境"
      VpcId:
        default: "VPC ID"
      SubnetIds:
        default: "子网 IDs"
      SecurityGroupIds:
        default: "安全组 IDs"
      GlueVersion:
        default: "Glue 版本"
      WorkerType:
        default: "Worker 类型"
      NumberOfWorkers:
        default: "Worker 数量"
      EnableMonitoring:
        default: "启用监控"
      LogRetentionDays:
        default: "日志保留天数"
      NestedStacksBucket:
        default: "嵌套栈 S3 存储桶"

Parameters:
  ProjectName:
    Type: String
    Default: WORKFLOW_NAME_PLACEHOLDER
    Description: 项目名称
    AllowedPattern: '^[a-z][a-z0-9-]*$'
    ConstraintDescription: 必须以小写字母开头，只能包含小写字母、数字和连字符
  
  Environment:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - test
      - staging
      - prod
    Description: 部署环境
  
  VpcId:
    Type: String
    Default: ""
    Description: VPC ID（可选，用于 VPC 内部署）
  
  SubnetIds:
    Type: CommaDelimitedList
    Default: ""
    Description: 子网 IDs，逗号分隔（可选）
  
  SecurityGroupIds:
    Type: CommaDelimitedList
    Default: ""
    Description: 安全组 IDs，逗号分隔（可选）
  
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
      - G.4X
      - G.8X
      - G.025X
      - Z.2X
    Description: Worker 类型
  
  NumberOfWorkers:
    Type: Number
    Default: 2
    MinValue: 2
    MaxValue: 299
    Description: Worker 数量
  
  EnableMonitoring:
    Type: String
    Default: "true"
    AllowedValues:
      - "true"
      - "false"
    Description: 是否启用增强监控
  
  LogRetentionDays:
    Type: Number
    Default: 7
    AllowedValues:
      - 1
      - 3
      - 5
      - 7
      - 14
      - 30
      - 60
      - 90
      - 120
      - 150
      - 180
      - 365
    Description: CloudWatch 日志保留天数
  
  NestedStacksBucket:
    Type: String
    Default: ""
    Description: 存储嵌套栈模板的 S3 存储桶（如使用嵌套栈）

Mappings:
  EnvironmentConfig:
    dev:
      LogLevel: DEBUG
      MaxRetries: 0
      Timeout: 2880
      AlarmThreshold: 2
    test:
      LogLevel: INFO
      MaxRetries: 1
      Timeout: 2880
      AlarmThreshold: 1
    staging:
      LogLevel: INFO
      MaxRetries: 1
      Timeout: 4320
      AlarmThreshold: 1
    prod:
      LogLevel: WARN
      MaxRetries: 2
      Timeout: 4320
      AlarmThreshold: 1

Conditions:
  IsProduction: !Equals [!Ref Environment, prod]
  IsDevelopment: !Equals [!Ref Environment, dev]
  HasVpcConfig: !Not [!Equals [!Ref VpcId, ""]]
  EnableMonitoringCondition: !Equals [!Ref EnableMonitoring, "true"]
  UseNestedStacks: !Not [!Equals [!Ref NestedStacksBucket, ""]]

Resources:
  # ===========================================
  # IAM 角色 - Glue 服务角色
  # ===========================================
  GlueServiceRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-glue-role-${Environment}'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: glue.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole'
      Policies:
        - PolicyName: GlueS3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:PutObject'
                  - 's3:DeleteObject'
                  - 's3:ListBucket'
                Resource:
                  - !Sub 'arn:aws:s3:::${ProjectName}-*'
                  - !Sub 'arn:aws:s3:::${ProjectName}-*/*'
                  - !Sub 'arn:aws:s3:::aws-glue-*'
                  - !Sub 'arn:aws:s3:::aws-glue-*/*'
        - PolicyName: GlueLogsAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'logs:CreateLogGroup'
                  - 'logs:CreateLogStream'
                  - 'logs:PutLogEvents'
                Resource:
                  - !Sub 'arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws-glue/*'
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-glue-role-${Environment}'
        - Key: Environment
          Value: !Ref Environment
        - Key: Project
          Value: !Ref ProjectName

  # ===========================================
  # S3 存储桶 - 脚本和临时数据
  # ===========================================
  ScriptBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-glue-scripts-${Environment}-${AWS::AccountId}'
      VersioningConfiguration:
        Status: Enabled
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      LifecycleConfiguration:
        Rules:
          - Id: DeleteOldVersions
            Status: Enabled
            NoncurrentVersionExpirationInDays: 30
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-glue-scripts-${Environment}'
        - Key: Environment
          Value: !Ref Environment
        - Key: Project
          Value: !Ref ProjectName

  DataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-glue-data-${Environment}-${AWS::AccountId}'
      VersioningConfiguration:
        Status: !If [IsProduction, Enabled, Suspended]
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-glue-data-${Environment}'
        - Key: Environment
          Value: !Ref Environment
        - Key: Project
          Value: !Ref ProjectName

  # ===========================================
  # Glue 数据库
  # ===========================================
  GlueDatabase:
    Type: AWS::Glue::Database
    Properties:
      CatalogId: !Ref AWS::AccountId
      DatabaseInput:
        Name: !Sub '${ProjectName}_${Environment}'
        Description: !Sub '${ProjectName} Glue 数据库 - ${Environment}'
        LocationUri: !Sub 's3://${DataBucket}/'

  # ===========================================
  # Glue 工作流
  # ===========================================
  GlueWorkflow:
    Type: AWS::Glue::Workflow
    Properties:
      Name: !Sub '${ProjectName}-${Environment}'
      Description: WORKFLOW_DESC_PLACEHOLDER
      MaxConcurrentRuns: !If [IsProduction, 10, 3]
      Tags:
        Name: !Sub '${ProjectName}-${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName
        ManagedBy: CloudFormation
        CostCenter: DataEngineering

EOFMASTER

# 替换占位符
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
    sed -i '' "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
else
    sed -i "s|WORKFLOW_NAME_PLACEHOLDER|$WORKFLOW_NAME|g" $OUTPUT_FILE
    sed -i "s|WORKFLOW_DESC_PLACEHOLDER|$WORKFLOW_DESC|g" $OUTPUT_FILE
fi

# 添加所有作业
echo "   添加复杂作业定义..."
for i in $(seq 1 $JOB_COUNT); do
    JOB_FILE="$EXPORT_DIR/job-${i}.json"
    [ ! -f "$JOB_FILE" ] && JOB_FILE="$EXPORT_DIR/job.json"
    
    if [ -f "$JOB_FILE" ]; then
        SCRIPT_LOCATION=$(cat $JOB_FILE | grep -o 's3://[^"]*' | head -1)
        
        cat >> $OUTPUT_FILE << EOFJOB
  # ===========================================
  # Glue 作业 $i (复杂配置)
  # ===========================================
  GlueJob${i}:
    Type: AWS::Glue::Job
    Properties:
      Name: !Sub '\${ProjectName}-job${i}-\${Environment}'
      Role: !GetAtt GlueServiceRole.Arn
      Command:
        Name: glueetl
        ScriptLocation: !Sub 's3://\${ScriptBucket}/scripts/job${i}.py'
        PythonVersion: "3"
      DefaultArguments:
        '--job-bookmark-option': 'job-bookmark-enable'
        '--enable-metrics': ''
        '--enable-spark-ui': 'true'
        '--spark-event-logs-path': !Sub 's3://\${ScriptBucket}/sparkui-logs/'
        '--enable-continuous-cloudwatch-log': 'true'
        '--continuous-log-logGroup': !Sub '/aws-glue/jobs/\${ProjectName}-job${i}'
        '--job-language': 'python'
        '--TempDir': !Sub 's3://\${ScriptBucket}/temp/'
        '--enable-glue-datacatalog': ''
        '--additional-python-modules': 'pandas,numpy'
        '--conf': !Sub 'spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions'
      ExecutionProperty:
        MaxConcurrentRuns: !If [IsProduction, 5, 2]
      MaxRetries: !FindInMap [EnvironmentConfig, !Ref Environment, MaxRetries]
      Timeout: !FindInMap [EnvironmentConfig, !Ref Environment, Timeout]
      GlueVersion: !Ref GlueVersion
      WorkerType: !Ref WorkerType
      NumberOfWorkers: !Ref NumberOfWorkers
      SecurityConfiguration: !If
        - IsProduction
        - !Ref GlueSecurityConfiguration
        - !Ref AWS::NoValue
      Tags:
        Name: !Sub '\${ProjectName}-job${i}-\${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName
        JobIndex: '${i}'

EOFJOB
    fi
done

# 添加安全配置（生产环境）
cat >> $OUTPUT_FILE << 'EOFSECURITY'
  # ===========================================
  # Glue 安全配置（生产环境）
  # ===========================================
  GlueSecurityConfiguration:
    Type: AWS::Glue::SecurityConfiguration
    Condition: IsProduction
    Properties:
      Name: !Sub '${ProjectName}-security-config-${Environment}'
      EncryptionConfiguration:
        S3Encryptions:
          - S3EncryptionMode: SSE-S3
        CloudWatchEncryption:
          CloudWatchEncryptionMode: DISABLED
        JobBookmarksEncryption:
          JobBookmarksEncryptionMode: DISABLED

EOFSECURITY

# 添加触发器
echo "   添加触发器定义..."
for i in $(seq 1 $TRIGGER_COUNT); do
    TRIGGER_FILE="$EXPORT_DIR/trigger-${i}.json"
    [ ! -f "$TRIGGER_FILE" ] && TRIGGER_FILE="$EXPORT_DIR/trigger.json"
    
    if [ -f "$TRIGGER_FILE" ]; then
        TRIGGER_TYPE=$(cat $TRIGGER_FILE | grep -o '"Type": "[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "ON_DEMAND")
        
        cat >> $OUTPUT_FILE << EOFTRIGGER
  GlueTrigger${i}:
    Type: AWS::Glue::Trigger
    Properties:
      Name: !Sub '\${ProjectName}-trigger${i}-\${Environment}'
      Type: $TRIGGER_TYPE
      WorkflowName: !Ref GlueWorkflow
      Actions:
        - JobName: !Ref GlueJob${i}
          Timeout: !FindInMap [EnvironmentConfig, !Ref Environment, Timeout]
      Tags:
        Name: !Sub '\${ProjectName}-trigger${i}-\${Environment}'
        Environment: !Ref Environment
        Project: !Ref ProjectName

EOFTRIGGER
    fi
done

# 添加监控和告警
cat >> $OUTPUT_FILE << 'EOFMONITORING'
  # ===========================================
  # CloudWatch 日志组
  # ===========================================
  WorkflowLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: EnableMonitoringCondition
    Properties:
      LogGroupName: !Sub '/aws-glue/workflows/${ProjectName}-${Environment}'
      RetentionInDays: !Ref LogRetentionDays

  # ===========================================
  # SNS 主题 - 告警通知
  # ===========================================
  AlarmTopic:
    Type: AWS::SNS::Topic
    Condition: EnableMonitoringCondition
    Properties:
      TopicName: !Sub '${ProjectName}-glue-alarms-${Environment}'
      DisplayName: !Sub '${ProjectName} Glue 作业告警'
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-glue-alarms-${Environment}'
        - Key: Environment
          Value: !Ref Environment
        - Key: Project
          Value: !Ref ProjectName

  # ===========================================
  # CloudWatch 告警 - 作业失败
  # ===========================================
  JobFailureAlarm:
    Type: AWS::CloudWatch::Alarm
    Condition: EnableMonitoringCondition
    Properties:
      AlarmName: !Sub '${ProjectName}-job-failures-${Environment}'
      AlarmDescription: Glue 作业失败告警
      MetricName: glue.driver.aggregate.numFailedTasks
      Namespace: Glue
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: !FindInMap [EnvironmentConfig, !Ref Environment, AlarmThreshold]
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlarmTopic
      TreatMissingData: notBreaching

EOFMONITORING

# 添加输出
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
  
  GlueServiceRoleArn:
    Description: Glue 服务角色 ARN
    Value: !GetAtt GlueServiceRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-GlueServiceRoleArn'
  
  ScriptBucketName:
    Description: 脚本存储桶名称
    Value: !Ref ScriptBucket
    Export:
      Name: !Sub '${AWS::StackName}-ScriptBucketName'
  
  DataBucketName:
    Description: 数据存储桶名称
    Value: !Ref DataBucket
    Export:
      Name: !Sub '${AWS::StackName}-DataBucketName'
  
  GlueDatabaseName:
    Description: Glue 数据库名称
    Value: !Ref GlueDatabase
    Export:
      Name: !Sub '${AWS::StackName}-GlueDatabaseName'
EOFOUTPUT

# 添加作业输出
for i in $(seq 1 $JOB_COUNT); do
    cat >> $OUTPUT_FILE << EOFJOBOUT
  
  Job${i}Name:
    Description: Glue 作业 $i 名称
    Value: !Ref GlueJob${i}
    Export:
      Name: !Sub '\${AWS::StackName}-Job${i}Name'
EOFJOBOUT
done

# 添加监控输出
cat >> $OUTPUT_FILE << 'EOFMONOUT'
  
  AlarmTopicArn:
    Description: 告警 SNS 主题 ARN
    Condition: EnableMonitoringCondition
    Value: !Ref AlarmTopic
    Export:
      Name: !Sub '${AWS::StackName}-AlarmTopicArn'
  
  StackInfo:
    Description: CloudFormation 堆栈详细信息
    Value: !Sub |
      堆栈名称: ${AWS::StackName}
      区域: ${AWS::Region}
      账号: ${AWS::AccountId}
      环境: ${Environment}
      项目: ${ProjectName}
      Glue 版本: ${GlueVersion}
      Worker 类型: ${WorkerType}
EOFMONOUT

echo "✅ 复杂项目主栈模板已生成: $OUTPUT_FILE"
echo "   包含: $JOB_COUNT 个作业, $TRIGGER_COUNT 个触发器"
echo "   特性: IAM 角色, S3 存储桶, 监控告警, 安全配置"

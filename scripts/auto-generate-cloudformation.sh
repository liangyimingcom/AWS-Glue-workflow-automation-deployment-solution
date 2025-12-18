#!/bin/bash

# AWS Glue CloudFormation 自动生成工具
# 智能检测项目复杂度并选择最佳生成方法
# 使用方法: ./auto-generate-cloudformation.sh [工作流名称] [AWS配置文件] [区域]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 参数
WORKFLOW_NAME=${1:-helloworld}
AWS_PROFILE=${2:-default}
AWS_REGION=${3:-us-east-1}
OUTPUT_DIR="./cloudformation-export"

# 复杂度级别
COMPLEXITY_LEVEL=""
RESOURCE_COUNT=0

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AWS Glue CloudFormation 自动生成工具                    ║${NC}"
echo -e "${BLUE}║  智能检测 • 自动生成 • 零代码配置                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📋 配置参数:${NC}"
echo "   工作流名称: $WORKFLOW_NAME"
echo "   AWS配置文件: $AWS_PROFILE"
echo "   区域: $AWS_REGION"
echo "   输出目录: $OUTPUT_DIR"
echo ""

# 创建输出目录
mkdir -p $OUTPUT_DIR

# ========================================
# 步骤 1: 智能资源发现
# ========================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔍 步骤 1/5: 智能资源发现${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 检测工作流是否存在
echo "   检查 Glue 工作流..."
if aws glue get-workflow --name $WORKFLOW_NAME --profile $AWS_PROFILE --region $AWS_REGION &>/dev/null; then
    echo -e "   ${GREEN}✅ 找到工作流: $WORKFLOW_NAME${NC}"
    RESOURCE_COUNT=$((RESOURCE_COUNT + 1))
else
    echo -e "   ${RED}❌ 工作流不存在: $WORKFLOW_NAME${NC}"
    echo -e "   ${YELLOW}💡 提示: 请确认工作流名称或先创建工作流${NC}"
    exit 1
fi

# 发现相关作业
echo "   查找相关 Glue 作业..."
JOBS=$(aws glue list-jobs \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query "JobNames[?contains(@, '${WORKFLOW_NAME}')]" \
    --output text)

if [ -z "$JOBS" ]; then
    JOBS="${WORKFLOW_NAME}-job"
fi

JOB_COUNT=$(echo $JOBS | wc -w)
RESOURCE_COUNT=$((RESOURCE_COUNT + JOB_COUNT))
echo -e "   ${GREEN}✅ 找到 $JOB_COUNT 个作业${NC}"

# 发现触发器
echo "   查找相关 Glue 触发器..."
TRIGGERS=$(aws glue list-triggers \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query "TriggerNames[?contains(@, '${WORKFLOW_NAME}')]" \
    --output text)

if [ -z "$TRIGGERS" ]; then
    TRIGGERS="${WORKFLOW_NAME}-trigger"
fi

TRIGGER_COUNT=$(echo $TRIGGERS | wc -w)
RESOURCE_COUNT=$((RESOURCE_COUNT + TRIGGER_COUNT))
echo -e "   ${GREEN}✅ 找到 $TRIGGER_COUNT 个触发器${NC}"

# 发现爬虫（可选）
echo "   查找相关 Glue 爬虫..."
CRAWLERS=$(aws glue list-crawlers \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query "CrawlerNames[?contains(@, '${WORKFLOW_NAME}')]" \
    --output text 2>/dev/null || echo "")

CRAWLER_COUNT=$(echo $CRAWLERS | wc -w)
if [ $CRAWLER_COUNT -gt 0 ]; then
    RESOURCE_COUNT=$((RESOURCE_COUNT + CRAWLER_COUNT))
    echo -e "   ${GREEN}✅ 找到 $CRAWLER_COUNT 个爬虫${NC}"
else
    echo -e "   ${YELLOW}⚠️  未找到爬虫（可选资源）${NC}"
fi

echo ""
echo -e "   ${BLUE}📊 资源统计:${NC}"
echo "      总资源数: $RESOURCE_COUNT"
echo "      - 工作流: 1"
echo "      - 作业: $JOB_COUNT"
echo "      - 触发器: $TRIGGER_COUNT"
echo "      - 爬虫: $CRAWLER_COUNT"

# ========================================
# 步骤 2: 复杂度评估
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎯 步骤 2/5: 项目复杂度评估${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $RESOURCE_COUNT -le 5 ]; then
    COMPLEXITY_LEVEL="简单"
    COMPLEXITY_COLOR=$GREEN
    RECOMMENDED_METHOD="方法一: CLI + Bash 脚本"
elif [ $RESOURCE_COUNT -le 15 ]; then
    COMPLEXITY_LEVEL="中等"
    COMPLEXITY_COLOR=$YELLOW
    RECOMMENDED_METHOD="方法一: CLI + Bash 脚本（增强版）"
else
    COMPLEXITY_LEVEL="复杂"
    COMPLEXITY_COLOR=$RED
    RECOMMENDED_METHOD="方法四: AWS CDK 或 方法二: Resource Groups"
fi

echo -e "   ${COMPLEXITY_COLOR}复杂度级别: $COMPLEXITY_LEVEL${NC}"
echo -e "   推荐方法: $RECOMMENDED_METHOD"
echo ""

# ========================================
# 步骤 3: 导出资源配置
# ========================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📦 步骤 3/5: 导出资源配置${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 导出工作流
echo "   导出工作流配置..."
aws glue get-workflow \
    --name $WORKFLOW_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --output json > $OUTPUT_DIR/workflow.json
echo -e "   ${GREEN}✅ 工作流配置已保存${NC}"

# 导出所有作业
echo "   导出作业配置..."
JOB_INDEX=1
for JOB in $JOBS; do
    aws glue get-job \
        --job-name $JOB \
        --profile $AWS_PROFILE \
        --region $AWS_REGION \
        --output json > $OUTPUT_DIR/job-${JOB_INDEX}.json
    echo -e "   ${GREEN}✅ 作业 $JOB_INDEX: $JOB${NC}"
    JOB_INDEX=$((JOB_INDEX + 1))
done

# 保存主要作业引用
cp $OUTPUT_DIR/job-1.json $OUTPUT_DIR/job.json 2>/dev/null || true

# 导出所有触发器
echo "   导出触发器配置..."
TRIGGER_INDEX=1
for TRIGGER in $TRIGGERS; do
    aws glue get-trigger \
        --name $TRIGGER \
        --profile $AWS_PROFILE \
        --region $AWS_REGION \
        --output json > $OUTPUT_DIR/trigger-${TRIGGER_INDEX}.json 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✅ 触发器 $TRIGGER_INDEX: $TRIGGER${NC}"
    fi
    TRIGGER_INDEX=$((TRIGGER_INDEX + 1))
done

# 保存主要触发器引用
cp $OUTPUT_DIR/trigger-1.json $OUTPUT_DIR/trigger.json 2>/dev/null || true

# 导出爬虫（如果存在）
if [ $CRAWLER_COUNT -gt 0 ]; then
    echo "   导出爬虫配置..."
    CRAWLER_INDEX=1
    for CRAWLER in $CRAWLERS; do
        aws glue get-crawler \
            --name $CRAWLER \
            --profile $AWS_PROFILE \
            --region $AWS_REGION \
            --output json > $OUTPUT_DIR/crawler-${CRAWLER_INDEX}.json 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "   ${GREEN}✅ 爬虫 $CRAWLER_INDEX: $CRAWLER${NC}"
        fi
        CRAWLER_INDEX=$((CRAWLER_INDEX + 1))
    done
fi

# 导出脚本文件
echo "   导出 Glue 脚本文件..."
SCRIPT_LOCATION=$(cat $OUTPUT_DIR/job.json | grep -o 's3://[^"]*' | head -1)
if [ ! -z "$SCRIPT_LOCATION" ]; then
    SCRIPT_NAME=$(basename $SCRIPT_LOCATION)
    aws s3 cp $SCRIPT_LOCATION $OUTPUT_DIR/$SCRIPT_NAME \
        --profile $AWS_PROFILE \
        --region $AWS_REGION 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✅ 脚本已下载: $SCRIPT_NAME${NC}"
    fi
fi

# ========================================
# 步骤 4: 生成 CloudFormation 模板
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔨 步骤 4/5: 生成 CloudFormation 模板${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 根据复杂度选择生成器
if [ "$COMPLEXITY_LEVEL" = "简单" ]; then
    echo "   使用简单模板生成器..."
    ./scripts/generate-simple-cloudformation.sh "$OUTPUT_DIR" "$WORKFLOW_NAME"
elif [ "$COMPLEXITY_LEVEL" = "中等" ]; then
    echo "   使用中等复杂度模板生成器..."
    ./scripts/generate-medium-cloudformation.sh "$OUTPUT_DIR" "$WORKFLOW_NAME"
else
    echo "   使用复杂模板生成器..."
    ./scripts/generate-complex-cloudformation.sh "$OUTPUT_DIR" "$WORKFLOW_NAME"
fi

# 如果专用生成器不存在，使用默认生成器
if [ ! -f "$OUTPUT_DIR/cloudformation.yaml" ]; then
    echo "   使用默认生成器..."
    if [ -f "./scripts/generate-cloudformation-from-export.sh" ]; then
        ./scripts/generate-cloudformation-from-export.sh
        # 重命名为标准名称
        if [ -f "$OUTPUT_DIR/generated-cloudformation.yaml" ]; then
            mv "$OUTPUT_DIR/generated-cloudformation.yaml" "$OUTPUT_DIR/cloudformation.yaml"
        fi
    fi
fi

echo -e "   ${GREEN}✅ CloudFormation 模板已生成${NC}"

# ========================================
# 步骤 5: 生成文档和摘要
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📝 步骤 5/5: 生成文档和摘要${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 生成部署摘要
cat > $OUTPUT_DIR/deployment-summary.md << EOF
# AWS Glue 部署摘要

## 项目信息

- **工作流名称**: $WORKFLOW_NAME
- **复杂度级别**: $COMPLEXITY_LEVEL
- **资源总数**: $RESOURCE_COUNT
- **导出时间**: $(date '+%Y-%m-%d %H:%M:%S')
- **AWS 区域**: $AWS_REGION
- **AWS 账号**: $(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text 2>/dev/null || echo "未知")

## 资源清单

### Glue 工作流 (1)
- $WORKFLOW_NAME

### Glue 作业 ($JOB_COUNT)
$(for JOB in $JOBS; do echo "- $JOB"; done)

### Glue 触发器 ($TRIGGER_COUNT)
$(for TRIGGER in $TRIGGERS; do echo "- $TRIGGER"; done)

$(if [ $CRAWLER_COUNT -gt 0 ]; then
echo "### Glue 爬虫 ($CRAWLER_COUNT)"
for CRAWLER in $CRAWLERS; do echo "- $CRAWLER"; done
fi)

## 导出文件

\`\`\`
cloudformation-export/
├── cloudformation.yaml          # 主 CloudFormation 模板
├── workflow.json                # 工作流配置
├── job-*.json                   # 作业配置文件
├── trigger-*.json               # 触发器配置文件
$(if [ $CRAWLER_COUNT -gt 0 ]; then echo "├── crawler-*.json               # 爬虫配置文件"; fi)
├── deployment-summary.md        # 本文件
└── resource-summary.txt         # 资源摘要
\`\`\`

## 部署步骤

### 1. 验证模板

\`\`\`bash
aws cloudformation validate-template \\
  --template-body file://$OUTPUT_DIR/cloudformation.yaml
\`\`\`

### 2. 部署到目标账号

#### 开发环境
\`\`\`bash
aws cloudformation deploy \\
  --template-file $OUTPUT_DIR/cloudformation.yaml \\
  --stack-name ${WORKFLOW_NAME}-dev-stack \\
  --capabilities CAPABILITY_IAM \\
  --parameter-overrides \\
      Environment=dev \\
      ProjectName=$WORKFLOW_NAME \\
  --profile <目标配置文件> \\
  --region $AWS_REGION
\`\`\`

#### 测试环境
\`\`\`bash
aws cloudformation deploy \\
  --template-file $OUTPUT_DIR/cloudformation.yaml \\
  --stack-name ${WORKFLOW_NAME}-test-stack \\
  --capabilities CAPABILITY_IAM \\
  --parameter-overrides \\
      Environment=test \\
      ProjectName=$WORKFLOW_NAME \\
  --profile <目标配置文件> \\
  --region $AWS_REGION
\`\`\`

#### 生产环境
\`\`\`bash
aws cloudformation deploy \\
  --template-file $OUTPUT_DIR/cloudformation.yaml \\
  --stack-name ${WORKFLOW_NAME}-prod-stack \\
  --capabilities CAPABILITY_IAM \\
  --parameter-overrides \\
      Environment=prod \\
      ProjectName=$WORKFLOW_NAME \\
  --profile <目标配置文件> \\
  --region $AWS_REGION
\`\`\`

### 3. 启动工作流

\`\`\`bash
# 启动工作流
aws glue start-workflow-run \\
  --name ${WORKFLOW_NAME}-dev \\
  --profile <目标配置文件> \\
  --region $AWS_REGION

# 查看工作流运行状态
aws glue get-workflow-run \\
  --name ${WORKFLOW_NAME}-dev \\
  --run-id <run-id> \\
  --profile <目标配置文件> \\
  --region $AWS_REGION
\`\`\`

## 清理资源

\`\`\`bash
# 删除 CloudFormation 堆栈
aws cloudformation delete-stack \\
  --stack-name ${WORKFLOW_NAME}-dev-stack \\
  --profile <目标配置文件> \\
  --region $AWS_REGION
\`\`\`

## 注意事项

1. **IAM 角色**: 确保目标账号有相应的 IAM 角色，或在模板中创建新角色
2. **S3 脚本**: 需要手动上传 Glue 脚本到目标账号的 S3 存储桶
3. **依赖资源**: 如使用了数据库或连接，需要先在目标账号创建
4. **跨区域**: 如需部署到不同区域，注意修改区域相关配置

## 推荐方法

根据项目复杂度 **$COMPLEXITY_LEVEL**，推荐使用：

**$RECOMMENDED_METHOD**

查看详细说明：[CloudFormation 打包方法指南](../docs/CLOUDFORMATION_PACKAGING_GUIDE.md)

EOF

echo -e "   ${GREEN}✅ 部署摘要已生成: deployment-summary.md${NC}"

# 生成资源摘要文本
cat > $OUTPUT_DIR/resource-summary.txt << EOF
AWS Glue 资源导出摘要
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
导出时间: $(date)
工作流名称: $WORKFLOW_NAME
复杂度级别: $COMPLEXITY_LEVEL
AWS 区域: $AWS_REGION
资源总数: $RESOURCE_COUNT

资源统计:
  • 工作流: 1
  • 作业: $JOB_COUNT
  • 触发器: $TRIGGER_COUNT
  • 爬虫: $CRAWLER_COUNT

推荐部署方法:
  $RECOMMENDED_METHOD

下一步:
  1. 查看部署摘要: cat $OUTPUT_DIR/deployment-summary.md
  2. 验证模板: aws cloudformation validate-template --template-body file://$OUTPUT_DIR/cloudformation.yaml
  3. 部署到目标账号
EOF

echo -e "   ${GREEN}✅ 资源摘要已生成: resource-summary.txt${NC}"

# ========================================
# 完成总结
# ========================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ CloudFormation 模板生成完成！                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 生成统计:${NC}"
echo "   • 复杂度级别: $COMPLEXITY_LEVEL"
echo "   • 资源总数: $RESOURCE_COUNT"
echo "   • 输出目录: $OUTPUT_DIR"
echo ""
echo -e "${BLUE}📁 生成的文件:${NC}"
echo "   • cloudformation.yaml        - CloudFormation 模板"
echo "   • deployment-summary.md      - 部署说明文档"
echo "   • resource-summary.txt       - 资源摘要"
echo "   • workflow.json              - 工作流配置"
echo "   • job-*.json                 - 作业配置"
echo "   • trigger-*.json             - 触发器配置"
echo ""
echo -e "${BLUE}🚀 快速部署:${NC}"
echo ""
echo "   # 1. 验证模板"
echo "   aws cloudformation validate-template \\"
echo "     --template-body file://$OUTPUT_DIR/cloudformation.yaml"
echo ""
echo "   # 2. 部署到目标账号"
echo "   aws cloudformation deploy \\"
echo "     --template-file $OUTPUT_DIR/cloudformation.yaml \\"
echo "     --stack-name ${WORKFLOW_NAME}-stack \\"
echo "     --capabilities CAPABILITY_IAM \\"
echo "     --parameter-overrides Environment=dev ProjectName=$WORKFLOW_NAME"
echo ""
echo -e "${BLUE}📖 详细文档:${NC}"
echo "   • 部署说明: cat $OUTPUT_DIR/deployment-summary.md"
echo "   • 打包方法指南: docs/CLOUDFORMATION_PACKAGING_GUIDE.md"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

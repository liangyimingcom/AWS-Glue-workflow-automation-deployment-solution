# CloudFormation 导出目录

本目录包含自动生成的 CloudFormation 模板和相关资源文件。

## 📁 目录结构

```
cloudformation-export/
├── cloudformation.yaml          # 主 CloudFormation 模板（部署用）
├── deployment-summary.md        # 部署说明文档（Markdown格式）
├── resource-summary.txt         # 资源摘要（文本格式）
├── workflow.json                # Glue 工作流原始配置
├── job-*.json                   # Glue 作业原始配置
├── trigger-*.json               # Glue 触发器原始配置
├── crawler-*.json               # Glue 爬虫原始配置（如有）
└── scripts/                     # Glue 脚本文件
    └── *.py                     # Python ETL 脚本
```

## 🚀 快速部署

### 步骤 1: 验证模板

```bash
aws cloudformation validate-template \
  --template-body file://cloudformation.yaml
```

### 步骤 2: 部署到 AWS

```bash
aws cloudformation deploy \
  --template-file cloudformation.yaml \
  --stack-name <your-stack-name> \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      Environment=dev \
      ProjectName=<your-project-name>
```

### 步骤 3: 验证部署

```bash
# 查看堆栈状态
aws cloudformation describe-stacks \
  --stack-name <your-stack-name>

# 查看 Glue 工作流
aws glue get-workflow --name <workflow-name>
```

## 📖 详细文档

- **deployment-summary.md**: 完整的部署指南
- **../docs/AUTO_GENERATION_METHODS.md**: 自动生成方法详解
- **../docs/CLOUDFORMATION_PACKAGING_GUIDE.md**: CloudFormation 打包方法指南

## 💡 提示

1. 部署前请确保已配置 AWS CLI 凭证
2. 确保目标账号有足够的权限创建 Glue 资源
3. 如使用 S3 脚本，需先上传脚本到目标账号的 S3 存储桶
4. 生产环境部署建议先创建变更集（changeset）预览变更

## 🆘 需要帮助？

查看主项目文档或提交 Issue: [项目地址](https://github.com/liangyimingcom/AWS-Glue-workflow-automation-deployment-solution)

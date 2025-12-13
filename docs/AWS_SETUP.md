# AWS 配置教程

## 🎯 概述

本文档介绍如何在不同操作系统上配置 AWS CLI 和创建访问密钥。

## 📋 前置条件

- AWS 账号
- 管理员权限或 IAM 权限

## 🔑 步骤1: 创建 AWS 访问密钥 (AK/SK)

### 1.1 登录 AWS 控制台

访问 [AWS Console](https://console.aws.amazon.com/)

### 1.2 创建 IAM 用户（如果还没有）

```mermaid
flowchart TD
    A[IAM控制台] --> B[用户]
    B --> C[创建用户]
    C --> D[设置用户名]
    D --> E[选择访问类型]
    E --> F[编程访问]
    F --> G[附加权限策略]
    G --> H[创建用户]
    
    style H fill:#90EE90
```

**步骤**:
1. 打开 [IAM 控制台](https://console.aws.amazon.com/iam/)
2. 左侧菜单选择 **用户** → **创建用户**
3. 输入用户名（如：`glue-automation-user`）
4. 选择 **访问密钥 - 编程访问**
5. 点击 **下一步: 权限**

### 1.3 附加权限策略

**推荐策略**（根据需求选择）:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glue:*",
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "cloudformation:*",
        "iam:GetRole",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

或使用 AWS 托管策略:
- `AWSGlueConsoleFullAccess`
- `CloudFormationFullAccess`
- `AmazonS3ReadOnlyAccess`

### 1.4 下载访问密钥

```mermaid
graph LR
    A[创建完成] --> B[下载.csv文件]
    B --> C[保存到安全位置]
    C --> D[记录AK/SK]
    
    style D fill:#FFD700
```

**重要**:
- ⚠️ 这是**唯一**一次可以查看密钥的机会
- 📥 立即下载 `.csv` 文件
- 🔒 妥善保管，不要泄露

**文件内容示例**:
```
User name,Access key ID,Secret access key
glue-automation-user,AKIAIOSFODNN7EXAMPLE,wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## 💻 步骤2: 配置 AWS CLI

### 2.1 安装 AWS CLI

#### Windows

**方式1: MSI 安装程序**
```powershell
# 下载并运行安装程序
# https://awscli.amazonaws.com/AWSCLIV2.msi

# 验证安装
aws --version
```

**方式2: Chocolatey**
```powershell
choco install awscli
```

#### macOS

**方式1: Homebrew（推荐）**
```bash
brew install awscli
```

**方式2: 官方安装包**
```bash
# 下载安装包
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"

# 安装
sudo installer -pkg AWSCLIV2.pkg -target /
```

#### Linux

**方式1: 官方安装脚本（推荐）**
```bash
# 下载安装包
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# 解压
unzip awscliv2.zip

# 安装
sudo ./aws/install

# 验证
aws --version
```

**方式2: 包管理器**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install awscli

# CentOS/RHEL
sudo yum install awscli

# Fedora
sudo dnf install awscli
```

### 2.2 配置 AWS Profile

#### 方式1: 交互式配置（推荐）

```bash
aws configure --profile oversea1
```

**提示输入**:
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

#### 方式2: 手动编辑配置文件

**配置文件位置**:
- **Windows**: `C:\Users\<用户名>\.aws\credentials`
- **macOS/Linux**: `~/.aws/credentials`

**编辑 credentials 文件**:
```ini
[oversea1]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**编辑 config 文件**:
```ini
[profile oversea1]
region = us-east-1
output = json
```

### 2.3 验证配置

```bash
# 验证凭证
aws sts get-caller-identity --profile oversea1

# 预期输出
{
    "UserId": "AIDAJEXAMPLEID",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/glue-automation-user"
}
```

## 🔧 配置文件详解

### 目录结构

```
~/.aws/
├── credentials          # 访问密钥
└── config              # 配置选项
```

### credentials 文件格式

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY

[oversea1]
aws_access_key_id = ANOTHER_ACCESS_KEY_ID
aws_secret_access_key = ANOTHER_SECRET_ACCESS_KEY

[production]
aws_access_key_id = PROD_ACCESS_KEY_ID
aws_secret_access_key = PROD_SECRET_ACCESS_KEY
```

### config 文件格式

```ini
[default]
region = us-east-1
output = json

[profile oversea1]
region = us-west-2
output = table

[profile production]
region = eu-west-1
output = json
```

## 🌍 常用 AWS 区域

| 区域代码 | 区域名称 | 位置 |
|---------|---------|------|
| `us-east-1` | US East (N. Virginia) | 美国东部 |
| `us-west-2` | US West (Oregon) | 美国西部 |
| `eu-west-1` | Europe (Ireland) | 欧洲（爱尔兰） |
| `ap-southeast-1` | Asia Pacific (Singapore) | 亚太（新加坡） |
| `ap-northeast-1` | Asia Pacific (Tokyo) | 亚太（东京） |

## 🔒 安全最佳实践

### 1. 密钥管理

```mermaid
graph TB
    A[安全实践] --> B[定期轮换密钥]
    A --> C[使用IAM角色]
    A --> D[最小权限原则]
    A --> E[启用MFA]
    
    style A fill:#FFD700
```

- ✅ 定期轮换访问密钥（每90天）
- ✅ 不要在代码中硬编码密钥
- ✅ 使用 IAM 角色而非长期密钥
- ✅ 启用多因素认证（MFA）
- ✅ 监控密钥使用情况

### 2. 权限控制

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetWorkflow",
        "glue:GetJob",
        "glue:GetTrigger",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:glue:us-east-1:123456789012:workflow/*",
        "arn:aws:s3:::my-glue-scripts/*"
      ]
    }
  ]
}
```

### 3. 密钥泄露应对

如果密钥泄露：
1. 🚨 立即在 IAM 控制台禁用密钥
2. 🔄 创建新的访问密钥
3. 🔍 检查 CloudTrail 日志
4. 📧 通知安全团队

## 🧪 测试配置

### 基本测试

```bash
# 测试凭证
aws sts get-caller-identity --profile oversea1

# 测试 Glue 权限
aws glue list-workflows --profile oversea1

# 测试 S3 权限
aws s3 ls --profile oversea1
```

### 完整测试脚本

```bash
#!/bin/bash

PROFILE="oversea1"

echo "🔍 测试 AWS 配置..."

# 测试1: 验证身份
echo "1. 验证身份..."
aws sts get-caller-identity --profile $PROFILE

# 测试2: 列出 Glue 工作流
echo "2. 测试 Glue 权限..."
aws glue list-workflows --profile $PROFILE

# 测试3: 列出 S3 存储桶
echo "3. 测试 S3 权限..."
aws s3 ls --profile $PROFILE

echo "✅ 配置测试完成！"
```

## ❓ 常见问题

### Q1: 找不到 credentials 文件？

```bash
# 创建目录
mkdir -p ~/.aws

# 创建文件
touch ~/.aws/credentials
touch ~/.aws/config
```

### Q2: 权限被拒绝？

检查 IAM 策略是否包含所需权限：
```bash
aws iam list-attached-user-policies --user-name glue-automation-user
```

### Q3: 区域设置错误？

```bash
# 查看当前配置
aws configure list --profile oversea1

# 修改区域
aws configure set region us-east-1 --profile oversea1
```

### Q4: 如何使用多个 Profile？

```bash
# 方式1: 使用 --profile 参数
aws glue list-workflows --profile oversea1

# 方式2: 设置环境变量
export AWS_PROFILE=oversea1
aws glue list-workflows

# 方式3: 在脚本中指定
./export-glue-to-cloudformation.sh helloworld oversea1 us-east-1
```

## 🔗 相关资源

- [AWS CLI 官方文档](https://docs.aws.amazon.com/cli/)
- [IAM 用户指南](https://docs.aws.amazon.com/IAM/latest/UserGuide/)
- [AWS 安全最佳实践](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

---

**配置完成后**: 返回 [快速开始](../QUICKSTART.md) 继续使用本项目

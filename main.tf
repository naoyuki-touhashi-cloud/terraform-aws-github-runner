# ランダムIDの生成
resource "random_id" "random" {
  byte_length = 20
}
provider "aws" {
    region = "ap-northeast-1"
}

module "github-runner" {
  source  = "philips-labs/github-runner/aws"
  version = "v0.36.0"

  # 事前に作成したVPCを指定
  aws_region = "ap-northeast-1"
  vpc_id     = "vpc-0e8b491aa0bd1d3b0"
  subnet_ids = ["subnet-04686dd67deaa1893"]

  # 環境名(プレフィックス)
  environment = "production"

  # GithubAppの設定
  github_app = {
    key_base64     =    "N2FlZmZjNjY2YTQwYzM0MDU1MzM0MjM4ZjFhNWRjZDI2NTY4NWY3OQ=="
    id                     =    1218314
    webhook_secret =    random_id.random.hex
  }

  # 先にダウンロードしておいたLambdaのパスを指定
  webhook_lambda_zip = "C:\\Users\\tokyo\\Videos\\runners.zip"
  runner_binaries_syncer_lambda_zip = "C:\\Users\\tokyo\\Videos\\runner-binaries-syncer.zip"
  runners_lambda_zip = "C:\\Users\\tokyo\\Videos\\webhook.zip"
  enable_organization_runners       = false
  
  # OS指定
  runner_os = "windows"

  # ランナーのラベル指定
  runner_extra_labels = "default,example"

  # Runnerの立ち上げ待ち時間
  runner_boot_time_in_minutes = 20

  # webhookの実行を遅延させる(秒)
  delay_webhook_event = 5

  # スケールダウンチェックの頻度をcronで設定
  scale_down_schedule_expression = "cron(0 * * * ? *)"
  
  # ami
  ami_filter = {
    name = ["cloudflared-ec2"]
  }
  ami_owners = ["442376921734"]
}

resource "aws_lambda_function" "scale_down" {
  function_name = "scale_down"
  runtime       = "nodejs18.x"  # 最新のサポートされたランタイム
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"  # 必ずコード内のエントリポイントを確認
  # S3からLambdaコードを指定
  s3_bucket     = "terraform-aws-github-runner-prd-lambda-file-bucket"  # ここにバケット名を指定
  s3_key        = "runners.zip"  # S3バケット内のファイルパスを指定
}

resource "aws_lambda_function" "scale_up" {
  function_name = "scale_up"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  # S3からLambdaコードを指定
  s3_bucket     = "terraform-aws-github-runner-prd-lambda-file-bucket"  # ここにバケット名を指定
  s3_key        = "runner-binaries-syncer.zip"  # S3バケット内のファイルパスを指定
}

resource "aws_lambda_function" "webhook" {
  function_name = "webhook"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  # S3からLambdaコードを指定
  s3_bucket     = "terraform-aws-github-runner-prd-lambda-file-bucket"  # ここにバケット名を指定
  s3_key        = "webhook.zip"  # S3バケット内のファイルパスを指定
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda-policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::terraform-aws-github-runner-prd-lambda-file-bucket/*"
      },
      {
        Action   = "logs:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "webhook_secret" {
  name = "webhook-secret"
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id     = aws_secretsmanager_secret.webhook_secret.id
  secret_string = var.webhook_secret  # もしくは直接文字列
}

output "webhook_url" {
  value = "https://terraform-aws-github-runner"
}

output "webhook_secret" {
  value = var.webhook_secret
  sensitive = true
}

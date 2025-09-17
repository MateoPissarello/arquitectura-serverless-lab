provider "aws" {
  region = var.region
}

locals {
  orders_table          = "${var.project_name}-orders"
  orders_enriched_table = "${var.project_name}-orders-enriched"
  lambda_role_name      = "${var.project_name}-lambda-role"
}

# Empaquetar código de app/ en un zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/lambda_bundle.zip"
}

# Tablas DynamoDB
resource "aws_dynamodb_table" "orders" {
  name         = local.orders_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

resource "aws_dynamodb_table" "orders_enriched" {
  name         = local.orders_enriched_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }
}

# IAM: trust policy para Lambda
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = local.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Permisos mínimos: logs + dynamodb en ambas tablas
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    actions   = ["dynamodb:PutItem","dynamodb:GetItem","dynamodb:DescribeTable"]
    resources = [
      aws_dynamodb_table.orders.arn,
      aws_dynamodb_table.orders_enriched.arn
    ]

  }
  statement {
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
    ]
    resources = [aws_dynamodb_table.orders.stream_arn]
  }

  # Algunas cuentas requieren ListStreams/ListShards con resource "*"
  statement {
    actions = [
      "dynamodb:ListStreams",
      "dynamodb:ListShards"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.project_name}-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda HTTP (POST /orders)
resource "aws_lambda_function" "http" {
  function_name    = "${var.project_name}-orders-http"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler_http.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE = aws_dynamodb_table.orders.name
    }
  }
}

# Function URL pública (laboratorio). En prod usa IAM o JWT.
resource "aws_lambda_function_url" "http_url" {
  function_name      = aws_lambda_function.http.function_name
  authorization_type = "NONE"
}

# Lambda lectora de DynamoDB Streams
resource "aws_lambda_function" "stream" {
  function_name    = "${var.project_name}-orders-stream"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler_stream.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ENRICHED_TABLE = aws_dynamodb_table.orders_enriched.name
    }
  }
}

# Vincular stream de orders -> lambda stream
resource "aws_lambda_event_source_mapping" "dynamo_stream" {
  event_source_arn                     = aws_dynamodb_table.orders.stream_arn
  function_name                        = aws_lambda_function.stream.arn
  starting_position                    = "LATEST"
  maximum_batching_window_in_seconds   = 1
}


resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name = "lambda-http-gateway-dynamic-${random_string.suffix.result}"
}

data "template_file" "home_mjs" {
  template = file("${path.module}/external/home.mjs")
}

data "archive_file" "home_mjs" {
  type        = "zip"
  output_path = "${path.module}/external/home.zip"

  source {
    content  = data.template_file.home_mjs.rendered
    filename = "index.mjs"
  }
}

data "template_file" "colors_mjs" {
  template = file("${path.module}/external/colors.mjs")
}

data "archive_file" "colors_mjs" {
  type        = "zip"
  output_path = "${path.module}/external/colors.zip"

  source {
    content  = data.template_file.colors_mjs.rendered
    filename = "index.mjs"
  }
}

resource "aws_iam_role" "lambda" {
  name = "${local.name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "apigateway" {
  name = "${local.name}-apigateway"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "apigateway" {
  name = "${local.name}-apigateway"
  role = aws_iam_role.apigateway.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/apigateway/${local.name}-*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/${local.name}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name}-lambda"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name}-*"
      }
    ]
  })
}

resource "aws_lambda_function" "home" {
  function_name    = "${local.name}-home"
  filename         = "${path.module}/external/home.zip"
  handler          = "index.handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  source_code_hash = base64sha256(file("${path.module}/external/home.mjs"))
  timeout          = 5

  depends_on = [
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_lambda_function" "colors" {
  function_name    = "${local.name}-colors"
  filename         = "${path.module}/external/colors.zip"
  handler          = "index.handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  source_code_hash = base64sha256(file("${path.module}/external/colors.mjs"))
  timeout          = 5

  depends_on = [
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_apigatewayv2_api" "example" {
  name = local.name

  cors_configuration {
    allow_methods = ["GET", "POST"]
    allow_origins = ["*"]
  }

  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.example.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway.arn
    format = jsonencode({
      requestId      = "$context.requestId",
      sourceIp       = "$context.identity.sourceIp",
      httpMethod     = "$context.httpMethod",
      status         = "$context.status",
      protocol       = "$context.protocol",
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_lambda_permission" "home" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.home.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.example.id}/*/*/home"
}

resource "aws_apigatewayv2_integration" "home" {
  api_id                 = aws_apigatewayv2_api.example.id
  connection_type        = "INTERNET"
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.home.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "home" {
  api_id    = aws_apigatewayv2_api.example.id
  route_key = "GET /home"
  target    = "integrations/${aws_apigatewayv2_integration.home.id}"
}

resource "aws_lambda_permission" "colors_get" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.colors.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.example.id}/*/*/colors"
}

resource "aws_lambda_permission" "colors_get_by_id" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.colors.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.example.id}/*/*/colors/{id}"
}

resource "aws_apigatewayv2_integration" "colors_get" {
  api_id                 = aws_apigatewayv2_api.example.id
  connection_type        = "INTERNET"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.colors.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "colors_get" {
  api_id    = aws_apigatewayv2_api.example.id
  route_key = "GET /colors"
  target    = "integrations/${aws_apigatewayv2_integration.colors_get.id}"
}

resource "aws_apigatewayv2_route" "colors_get_by_id" {
  api_id    = aws_apigatewayv2_api.example.id
  route_key = "GET /colors/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.colors_get.id}"
}

resource "aws_lambda_permission" "colors_post" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.colors.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.example.id}/*/*/colors"
}

resource "aws_apigatewayv2_integration" "colors_post" {
  api_id                 = aws_apigatewayv2_api.example.id
  connection_type        = "INTERNET"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.colors.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "colors_post" {
  api_id    = aws_apigatewayv2_api.example.id
  route_key = "POST /colors"
  target    = "integrations/${aws_apigatewayv2_integration.colors_post.id}"
}

output "http_apigateway_endpoint_url" {
  value = aws_apigatewayv2_api.example.api_endpoint
}

output "home_url" {
  value = "${aws_apigatewayv2_api.example.api_endpoint}/home"
}

output "colors_url" {
  value = "${aws_apigatewayv2_api.example.api_endpoint}/colors"
}

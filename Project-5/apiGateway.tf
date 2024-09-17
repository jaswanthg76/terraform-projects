resource "aws_apigatewayv2_api" "main" {
  name          = "example-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "invoke" {
  api_id     = aws_apigatewayv2_api.main.id
  name       = "dev"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "main-integration" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri = aws_lambda_function.Api-invoke-lamdba.invoke_arn
}

resource "aws_apigatewayv2_route" "get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.main-integration.id}"
}

resource "aws_apigatewayv2_route" "post" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.main-integration.id}"
}

resource "aws_apigatewayv2_route" "put" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "PUT /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.main-integration.id}"
}

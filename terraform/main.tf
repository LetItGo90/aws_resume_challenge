
resource "aws_s3_bucket" "resume_site" {
  bucket = "austin-mundy-resume-site" 
}

resource "aws_s3_bucket_website_configuration" "resume_site" {
  bucket = aws_s3_bucket.resume_site.id
  
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "resume_site" {
  bucket = aws_s3_bucket.resume_site.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#resource "aws_s3_bucket_policy" "resume_site" {
 # bucket     = aws_s3_bucket.resume_site.id
  #depends_on = [aws_s3_bucket_public_access_block.resume_site]

  #policy = jsonencode({
   # Version = "2012-10-17"
    #Statement = [
     # {
      #  Sid       = "PublicReadGetObject"
       # Effect    = "Allow"
        #Principal = "*"
        #Action    = "s3:GetObject"
        #Resource  = "${aws_s3_bucket.resume_site.arn}/*"
      #}
    #]
  #})
#}

resource "aws_s3_object" "html" {
  bucket       = aws_s3_bucket.resume_site.id
  key          = "index.html"
  source       = "../frontend/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "css" {
  bucket       = aws_s3_bucket.resume_site.id
  key          = "styles.css"
  source       = "../frontend/styles.css"
  content_type = "text/css"
}

resource "aws_s3_object" "js" {
  bucket       = aws_s3_bucket.resume_site.id
  key          = "script.js"
  source       = "../frontend/script.js"
  content_type = "application/javascript"
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.resume_site.website_endpoint
}

data "aws_route53_zone" "main" {
  name = "austin-mundy-resume.com"
}

resource "aws_acm_certificate" "resume_cert" {
  domain_name       = "austin-mundy-resume.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.resume_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "resume_cert" {
  certificate_arn         = aws_acm_certificate.resume_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_origin_access_control" "resume_oac" {
  name                              = "resume-site-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "resume_site_cloudfront" {
  bucket = aws_s3_bucket.resume_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.resume_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "resume_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["austin-mundy-resume.com"]
  price_class         = "PriceClass_100"  

  origin {
    domain_name              = aws_s3_bucket.resume_site.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.resume_site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_oac.id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.resume_site.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress              = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.resume_cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.resume_cert]
}

resource "aws_route53_record" "resume_site" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "austin-mundy-resume.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.resume_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_public_access_block" "resume_site_locked" {
  bucket = aws_s3_bucket.resume_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_cloudfront_distribution.resume_distribution]
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.resume_distribution.domain_name
}

output "custom_domain" {
  value = "https://austin-mundy-resume.com"
}

resource "aws_dynamodb_table" "visitor_count" {
  name         = "resume-visitor-count"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "resume-visitor-counter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.visitor_count.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../backend/lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "visitor_counter" {
  filename         = "lambda_function.zip"
  function_name    = "resume-visitor-counter"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
}

resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "resume-visitor-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["https://austin-mundy-resume.com"]
    allow_methods = ["GET"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.visitor_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.visitor_counter.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "GET /visitor"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.api_stage.invoke_url}/visitor"
}
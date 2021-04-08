resource "aws_lambda_function" "myfunc" {
  description      = "Created by joseth during the lab"
  filename         = "lambda.py.zip"
  function_name    = "epcclambdafunction"
  handler          = "lambda.lambdahandler"
  source_code_hash = filebase64sha256("lambda.py.zip")
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = "python3.8"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
#S3 integration and CW logging
resource "aws_s3_bucket" "s3bucket" {
  bucket = "epccs3lambdatriggerexample"
}

resource "aws_cloudwatch_log_group" "cwlogs" {
  name              = "/aws/lambda/epcclambdafunction"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_epcc"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

#S3 trigger
resource "aws_s3_bucket_notification" "my-trigger" {
  bucket = aws_s3_bucket.s3bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.myfunc.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".txt"
  }
}

resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.myfunc.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3bucket.arn
}
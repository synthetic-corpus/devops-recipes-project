#########################################
# Creates IAM user and its polices for CD
#########################################

# 'resource' is something that is created in AWS.
resource "aws_iam_user" "cd" {
  name = "terraform-cd-guy"
}

resource "aws_iam_access_key" "cd" {
  user = aws_iam_user.cd.name
}

##########################################
# The Policies. Editted more frequently. #
##########################################

# 'data' is information that a resource will use when it is created
data "aws_iam_policy_document" "tf_backend_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.tf_state_bucket}"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetOjbect", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}/tf-state-deploy/*",
      "arn:aws:s3:::${var.tf_state_bucket}/tf-state-depoly-env/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:*table/${var.tf_state_lock_table}"]
  }
}

resource "aws_iam_policy" "tf_backend" {
  name        = "${aws_iam_user.cd.name}-terraform-s3-dynamodb"
  description = "Allower user to use S3 and DynamoDB for Terraform resources"
  policy      = data.aws_iam_policy_document.tf_backend_policy.json
}

# This attaches the policy to the user
resource "aws_iam_user_policy_attachment" "tf_backend" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.tf_backend.arn
}
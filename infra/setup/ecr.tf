######################################################
# This creates an AWS ECR (Elastic Container Register)
######################################################

resource "aws_ecr_repository" "app" {
  name                 = "recipe-app-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # for deleting images while testing/experimenting

  image_scanning_configuration {
    scan_on_push = false # no security scanning. True for serious deployments
  }
}

resource "aws_ecr_repository" "proxy" {
  name                 = "recipe-app-proxy"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # for deleting images while testing/experimenting

  image_scanning_configuration {
    scan_on_push = false # no security scanning. True for serious deployments
  }
}


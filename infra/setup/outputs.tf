output "cd_user_access_key_id" {
  description = "AWS key ID for CD user"
  value       = aws_iam_access_key.cd.id
}

output "cd_user_access_key_secret" {
  description = "Access Key for our super secret CD user"
  value       = aws_iam_access_key.cd.secret
  sensitive   = true # outputs in clear text only when specified!
}

output "ecr_repo_app" {
  description = "ECR Repo URL for the app image"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repo_proxy" {
  description = "ECR Repo URL for the proxy image"
  value       = aws_ecr_repository.proxy.repository_url
}
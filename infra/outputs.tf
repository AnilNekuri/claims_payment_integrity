output "producer_ecr_repository_url" {
  description = "ECR repository URL for the claim producer image."
  value       = aws_ecr_repository.producer.repository_url
}

output "rules_engine_ecr_repository_url" {
  description = "ECR repository URL for the rules engine image."
  value       = aws_ecr_repository.rules_engine.repository_url
}

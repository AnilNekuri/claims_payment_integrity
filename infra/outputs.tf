output "producer_ecr_repository_url" {
  description = "ECR repository URL for the claim producer image."
  value       = aws_ecr_repository.producer.repository_url
}

output "rules_engine_ecr_repository_url" {
  description = "ECR repository URL for the rules engine image."
  value       = aws_ecr_repository.rules_engine.repository_url
}

output "vpc_id" {
  description = "ID of the Phase 1 dev VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes, MSK, and RDS."
  value       = aws_subnet.private[*].id
}

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes."
  value       = aws_security_group.eks_nodes.id
}

output "msk_security_group_id" {
  description = "Security group ID for Amazon MSK."
  value       = aws_security_group.msk.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS PostgreSQL."
  value       = aws_security_group.rds.id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server."
  value       = aws_eks_cluster.main.endpoint
}

output "eks_node_group_name" {
  description = "Name of the EKS managed node group."
  value       = aws_eks_node_group.main.node_group_name
}

output "msk_cluster_arn" {
  description = "ARN of the Amazon MSK cluster."
  value       = aws_msk_cluster.main.arn
}

output "msk_bootstrap_brokers" {
  description = "Plaintext bootstrap broker connection string for Phase 1 VPC-only Kafka clients."
  value       = aws_msk_cluster.main.bootstrap_brokers
}

output "msk_bootstrap_brokers_tls" {
  description = "TLS bootstrap broker connection string for Kafka clients."
  value       = aws_msk_cluster.main.bootstrap_brokers_tls
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL hostname."
  value       = aws_db_instance.postgres.address
}

output "rds_database_name" {
  description = "RDS PostgreSQL database name."
  value       = aws_db_instance.postgres.db_name
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN containing RDS connection details."
  value       = aws_secretsmanager_secret.rds.arn
}

variable "aws_region" {
  description = "AWS region for Phase 1 resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "claims-integrity"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the Phase 1 dev VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.40.0.0/24", "10.40.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets used by EKS nodes, MSK, and RDS."
  type        = list(string)
  default     = ["10.40.10.0/24", "10.40.11.0/24"]
}

variable "eks_cluster_name" {
  description = "Name of the Phase 1 EKS cluster."
  type        = string
  default     = "claims-integrity-dev"
}

variable "eks_node_instance_types" {
  description = "Instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "msk_kafka_version" {
  description = "Kafka version for the Phase 1 Amazon MSK cluster."
  type        = string
  default     = "3.6.0"
}

variable "msk_broker_instance_type" {
  description = "Broker instance type for the Phase 1 Amazon MSK cluster."
  type        = string
  default     = "kafka.t3.small"
}

variable "msk_broker_volume_size" {
  description = "EBS volume size in GiB per MSK broker."
  type        = number
  default     = 20
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days."
  type        = number
  default     = 7
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for the Phase 1 RDS instance."
  type        = string
  default     = "16.3"
}

variable "rds_instance_class" {
  description = "Instance class for the Phase 1 RDS PostgreSQL instance."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage in GiB for RDS PostgreSQL."
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Maximum autoscaled storage in GiB for RDS PostgreSQL."
  type        = number
  default     = 50
}

variable "rds_db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "claims_integrity"
}

variable "rds_username" {
  description = "Master username for the Phase 1 RDS PostgreSQL instance."
  type        = string
  default     = "claims_app"
}

variable "rds_backup_retention_days" {
  description = "Backup retention period in days for the Phase 1 RDS instance."
  type        = number
  default     = 0
}

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

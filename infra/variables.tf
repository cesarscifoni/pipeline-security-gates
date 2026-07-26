variable "aws_region" {
  description = "AWS region principal"
  type        = string
  default     = "us-east-1"
}

variable "replica_region" {
  description = "AWS region para replicação cross-region"
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "Nome do bucket S3"
  type        = string
  default     = "pipeline-security-gates-demo"
}

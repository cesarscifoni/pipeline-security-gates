# ─── KMS KEY ────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# CKV2_AWS_64: KMS key com policy definida
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# ─── BUCKET PRINCIPAL ───────────────────────────────────────────────────────

resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name

  tags = {
    Environment = "dev"
    Project     = "pipeline-security-gates"
  }
}

# CKV_AWS_145: Encryption com KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# CKV_AWS_21: Versioning
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CKV2_AWS_6: Block Public Access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CKV_AWS_18: Access logging apontando para bucket de log
resource "aws_s3_bucket_logging" "example" {
  bucket        = aws_s3_bucket.example.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "logs/"
}

# CKV2_AWS_61 + CKV_AWS_300: Lifecycle com abort de uploads incompletos
resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CKV_AWS_144: Cross-region replication
resource "aws_s3_bucket_replication_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  role   = aws_iam_role.replication.arn

  depends_on = [aws_s3_bucket_versioning.example]

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
  }
}

# CKV2_AWS_62: Event notifications
resource "aws_s3_bucket_notification" "example" {
  bucket      = aws_s3_bucket.example.id
  eventbridge = true
}

# ─── BUCKET DE LOG ──────────────────────────────────────────────────────────

# checkov:skip=CKV_AWS_144: Bucket de log não requer replicação cross-region.
# Logs de acesso são dados operacionais, não dados de negócio — replicá-los
# criaria dependência circular (o bucket replica também precisaria de log).
# Decisão arquitetural documentada e aceita.
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.bucket_name}-logs"

  tags = {
    Environment = "dev"
    Project     = "pipeline-security-gates"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "log_bucket" {
  bucket      = aws_s3_bucket.log_bucket.id
  eventbridge = true
}

# ─── BUCKET REPLICA ─────────────────────────────────────────────────────────

resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "${var.bucket_name}-replica"

  tags = {
    Environment = "dev"
    Project     = "pipeline-security-gates"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  rule {
    id     = "expire-replica"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "replica" {
  provider    = aws.replica
  bucket      = aws_s3_bucket.replica.id
  eventbridge = true
}

# Bucket de log dedicado para a região replica
resource "aws_s3_bucket" "replica_log_bucket" {
  provider = aws.replica
  bucket   = "${var.bucket_name}-replica-logs"

  tags = {
    Environment = "dev"
    Project     = "pipeline-security-gates"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_log_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "replica_log_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "replica_log_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# checkov:skip=CKV_AWS_144: Bucket de log da replica não requer replicação cross-region.
# Mesma razão arquitetural do log_bucket principal — logs são dados operacionais.
resource "aws_s3_bucket_lifecycle_configuration" "replica_log_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica_log_bucket.id

  rule {
    id     = "expire-replica-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "replica_log_bucket" {
  provider    = aws.replica
  bucket      = aws_s3_bucket.replica_log_bucket.id
  eventbridge = true
}

# CKV_AWS_18: Access logging do bucket replica
resource "aws_s3_bucket_logging" "replica" {
  provider      = aws.replica
  bucket        = aws_s3_bucket.replica.id
  target_bucket = aws_s3_bucket.replica_log_bucket.id
  target_prefix = "logs/"
}

# ─── IAM REPLICATION ROLE ───────────────────────────────────────────────────

resource "aws_iam_role" "replication" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "s3-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = aws_s3_bucket.example.arn
      },
      {
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.example.arn}/*"
      },
      {
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.replica.arn}/*"
      }
    ]
  })
}

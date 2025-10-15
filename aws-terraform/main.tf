resource "aws_kms_key" "spring_petclinic_init" {
  description             = "Spring Petclinic KMS Key"
  deletion_window_in_days = 30
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "RSA_2048"
}

resource "aws_kms_alias" "spring_petclinic_init_alias" {
  name          = "alias/spring-petclinic-init"
  target_key_id = aws_kms_key.spring_petclinic_init.id
}

resource "aws_iam_role" "spring_petclinic_role" {
  name = "spring-petclinic-role-v2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "spring_petclinic_storage_policy" {
  name        = "spring-petclinic-storage-policy-v2"
  description = "Policy to allow access to S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:DeleteObject"]
      Resource = ["arn:aws:s3:::springpetclinicstorage/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.spring_petclinic_role.name
  policy_arn = aws_iam_policy.spring_petclinic_storage_policy.arn
}


resource "aws_s3_bucket" "spring_petclinic" {
  bucket = "springpetclinicstorage"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
        kms_master_key_id = aws_kms_key.spring_petclinic_init.id
      }
    }
  }
}


resource "aws_iam_policy" "kms_decrypt_policy" {
  name        = "spring-petclinic-kms-policy"
  description = "Allow decrypt using KMS key"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:Encrypt"]
      Resource = aws_kms_key.spring_petclinic_init.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_kms_policy" {
  role       = aws_iam_role.spring_petclinic_role.name
  policy_arn = aws_iam_policy.kms_decrypt_policy.arn
}

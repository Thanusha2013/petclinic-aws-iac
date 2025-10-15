resource "random_id" "suffix" {
  byte_length = 4
}

# KMS Key & Alias
resource "aws_kms_key" "spring_petclinic_init" {
  description             = "Spring Petclinic KMS Key"
  deletion_window_in_days = 30
  key_usage               = "ENCRYPT_DECRYPT"
}

resource "aws_kms_alias" "spring_petclinic_init_alias" {
  name          = "alias/spring-petclinic-init-${random_id.suffix.hex}"
  target_key_id = aws_kms_key.spring_petclinic_init.id
}

# IAM Role & Policies
resource "aws_iam_role" "spring_petclinic_role" {
  name = "spring-petclinic-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "spring_petclinic_storage_policy" {
  name        = "spring-petclinic-storage-policy-${random_id.suffix.hex}"
  description = "Policy to allow access to S3 bucket"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:DeleteObject"]
      Resource = ["arn:aws:s3:::springpetclinicstorage-${random_id.suffix.hex}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.spring_petclinic_role.name
  policy_arn = aws_iam_policy.spring_petclinic_storage_policy.arn
}

resource "aws_iam_policy" "kms_dec_

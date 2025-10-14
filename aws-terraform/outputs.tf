output "kms_key_id" {
  value = aws_kms_key.spring_petclinic_init.id
}

output "kms_key_arn" {
  value = aws_kms_key.spring_petclinic_init.arn
}


output "iam_role_arn" {
  value = aws_iam_role.spring_petclinic_role.arn
}

output "iam_role_name" {
  value = aws_iam_role.spring_petclinic_role.name
}

output "iam_policy_arn" {
  value = aws_iam_policy.spring_petclinic_storage_policy.arn
}


output "s3_bucket_id" {
  value = aws_s3_bucket.spring_petclinic.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.spring_petclinic.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.spring_petclinic.bucket
}

output "iam_role_name" {
  value = aws_iam_role.spring_petclinic_role.name
}

output "iam_role_arn" {
  value = aws_iam_role.spring_petclinic_role.arn
}



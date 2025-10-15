output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_sg.id
}

output "lb_security_group_id" {
  value = aws_security_group.lb_sg.id
}

output "kms_key_id" {
  value = aws_kms_key.spring_petclinic.id
}

output "kms_key_arn" {
  value = aws_kms_key.spring_petclinic.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.spring_petclinic.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.spring_petclinic.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.spring_petclinic.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.spring_petclinic.name
}

output "load_balancer_dns" {
  value = aws_lb.spring_petclinic.dns_name
}

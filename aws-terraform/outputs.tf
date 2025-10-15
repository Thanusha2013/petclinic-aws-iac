output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ecr_repo_url" {
  value = aws_ecr_repository.spring_petclinic.repository_url
}

output "alb_dns_name" {
  value = aws_lb.spring_petclinic.dns_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.spring_petclinic.bucket
}

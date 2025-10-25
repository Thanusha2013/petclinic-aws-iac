output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}

output "rds_endpoint" {
  value = aws_db_instance.spring_petclinic_rds.address
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.spring_petclinic.id
}

output "ecr_repo" {
  value = aws_ecr_repository.spring_petclinic.repository_url
}

output "load_balancer_dns" {
  value = aws_lb.spring_petclinic_lb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.spring_petclinic_rds.address
}

output "rds_db_name" {
  value = aws_db_instance.spring_petclinic_rds.db_name
}

output "ecr_repo" {
  value = aws_ecr_repository.spring_petclinic.repository_url
}

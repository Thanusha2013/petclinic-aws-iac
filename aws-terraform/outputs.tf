output "ecr_repo" {
  value = aws_ecr_repository.spring_petclinic.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.spring_petclinic_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.spring_petclinic_service.name
}

output "load_balancer_dns" {
  value = aws_lb.spring_petclinic_lb.dns_name
}

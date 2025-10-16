output "ecr_repo" {
  value = aws_ecr_repository.spring_petclinic.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

output "load_balancer_dns" {
  value = aws_lb.lb.dns_name
}

output "ecr_repo" {
  description = "ECR repository URL for Spring PetClinic"
  value       = aws_ecr_repository.spring_petclinic.repository_url
}

output "load_balancer_dns" {
  description = "DNS name of the Load Balancer"
  value       = aws_lb.spring_petclinic_lb.dns_name
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.cluster.name
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.service.name
}

output "ecr_repo" {
  value = aws_ecr_repository.repo.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}

output "service_name" {
  value = aws_ecs_service.service.name
}

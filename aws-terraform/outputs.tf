output "ecr_repo" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.spring_petclinic_repo.repository_url
}

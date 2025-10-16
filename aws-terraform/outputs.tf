output "load_balancer_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.spring_petclinic.dns_name
}

# Migration Report - Azure -> AWS for Spring PetClinic

## Objective
Migrate Spring PetClinic appStack (Azure) to AWS (ECS Fargate + ALB + RDS) using Terraform and automate via GitHub Actions.

## Steps performed
- Created StackGen appStack in Azure (spring-petclinic branch feature/azure) and resolved required template inputs.
- Exported IaC (azure-iac-export.zip) — keep this in the repo for reference.
- Created AWS Terraform config to provision VPC, subnets, ALB, ECS cluster/service, ECR, RDS MySQL, Secrets Manager, and CloudWatch logs.
- Added GitHub Actions workflow to run Terraform and to build/push Docker image + deploy to ECS.

## Mapping table (examples)
- Azure App Service -> AWS ECS Fargate + ALB
- Azure MySQL -> AWS RDS MySQL
- Azure Storage Account -> AWS S3 (not implemented in this template)
- Azure Key Vault -> AWS Secrets Manager

## Key decisions
- Use ECS Fargate for a serverless container runtime with ALB for routing.
- Use RDS MySQL for managed database parity with Azure Database for MySQL.
- Use Secrets Manager for DB credentials.

## Validation
- After CI runs, get ALB `alb_dns` output or check AWS console to access the app.

## Known limitations
- This repo does not include the original Azure exported files. Place `azure-iac-export.zip` in the repo root for reference.
- Dockerfile clones upstream repo; you can replace with local source if needed.


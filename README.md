# petclinic-aws-iac

Terraform IaC + GitHub Actions for deploying Spring PetClinic to AWS (ECS Fargate + ALB + RDS MySQL).

## Setup
1. Create a GitHub repo and push this project.
2. Add GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `DB_PASSWORD`.
3. Optionally add application source as a submodule or update Dockerfile to point to your fork:
   - By default Dockerfile clones spring-petclinic from the official repo. Replace `REPO_URL` ARG if needed.

## Run locally (optional)
```bash
cd terraform
terraform init
terraform plan -var="db_password=YOUR_DB_PASS"
terraform apply -var="db_password=YOUR_DB_PASS" -auto-approve
```

## CI/CD
Push to `main` to trigger GitHub Actions pipeline which will:
1. Run Terraform apply to create infra.
2. Build and push Docker image to ECR.
3. Force ECS service deployment to pick new image.

## Cleanup
Run `terraform destroy -var="db_password=YOUR_DB_PASS" -auto-approve` in the terraform folder to remove resources.

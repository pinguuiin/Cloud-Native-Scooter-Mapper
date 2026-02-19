# Terraform Deployment

This directory provisions the AWS serverless stack.

## Prerequisites

- Terraform 1.6+
- AWS credentials configured in your shell
- Lambda artifacts built in dist/

## Deploy

```bash
cd terraform
terraform init
terraform apply
```

## Frontend

Use the Terraform output `api_base_url` as `VITE_API_BASE_URL` when building the frontend.

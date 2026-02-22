# Cloud Native Scooter Mapper

This project is the cloud-native twin of the scooter mapper project the author built before.

## AWS Serverless Deployment with Terraform

## Security architecture

```text
terraform-admin (IAM User) + Access Key
            ↓
        terraform apply
            ↓ creates
---------------------------------
aws_iam_role.ingest
aws_iam_role.transform
aws_iam_role.api
aws_ecr_repository.ingest
aws_ecr_repository.transform
aws_ecr_repository.api
aws_lambda_function.*
aws_apigatewayv2_*
aws_cloudwatch_event_*
---------------------------------
            ↓ runtime
Lambda assumes its IAM role
Lambda pulls container images from ECR (via ECR repo policy)
API Gateway invokes Lambda via resource permission
EventBridge invokes Lambda via resource permission
```

## Setup

### Prerequisites
- Terraform 1.6+
- AWS IAM User account + credentials (access key) with AdministratorAccess assigned
- AWS CLI (for deploy/teardown commands)
- Docker (for Lambda container image build/push)
- Node.js + npm (frontend build)
- curl + jq (for test only)

### 0) Configure local AWS Credentials through AWS CLI profile (one-time)

Run the command below in your terminal:

```bash
aws configure
```

then input the IAM username and access key following the prompts.

### 1) Create ECR Repositories

```bash
cd terraform
terraform init

# ecr repo only needs to be created once unless running terraform destroy
terraform apply -target=aws_ecr_repository.ingest -target=aws_ecr_repository.transform -target=aws_ecr_repository.api
```

### 2) Build and Push Lambda Images to ECR

```bash
chmod +x scripts/build_and_push_ecr_images.sh
./scripts/build_and_push_ecr_images.sh latest
```

### 3) Provision AWS Resources

```bash
cd terraform
terraform apply
```

### 4) Deploy Frontend to S3 + CloudFront

```bash
./scripts/deploy_frontend.sh
```

You can also check the CloudFront domain from Terraform outputs:

```bash
terraform -chdir=terraform output -raw cloudfront_domain
```

### 5) Configure Overrides (Optional)

Create a tfvars file to override defaults (e.g. GBFS URL, bounds, CORS):

```bash
cd terraform
terraform apply -var-file=outputs.example.tfvars
```

### 6) Pause / Destroy Services

#### Case A: Pause EventBridge schedule

```bash
RULE_NAME=$(terraform -chdir=terraform output -raw ingest_schedule_rule_name)
aws events disable-rule --name "$RULE_NAME"
```

Remember to resume it before running `terraform plan/apply` to avoid Terraform drift:

```bash
aws events enable-rule --name "$RULE_NAME"
```

#### Case B: Full teardown (remove all AWS resources + local files)

```bash
cd terraform
terraform destroy
rm -rf frontend/dist frontend/node_modules
```

## API Endpoints

- /api/heatmap
- /api/heatmap/geojson
- /api/stats
- /api/health

## Tests

Run API consistency checks (health, stats, and cross-resolution total bike count):

```bash
chmod +x scripts/test_api.sh
./scripts/test_api.sh
```

Expected behavior:
- script prints `✅`/`❌` per check and a final summary
- exit code `0` when all checks pass, non-zero when any check fails

For cloud deployment debugging, replace `output_var_name` with the variable to be tested and run

```bash
terraform -chdir=terraform output -raw output_var_name
```

---

**Built for Portfolio Demonstration** | Ping | 2026
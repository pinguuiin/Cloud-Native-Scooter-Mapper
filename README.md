# Cloud Native Scooter Mapper

This project is the cloud-native twin of the [scooter heatmap](https://github.com/pinguuiin/Shared-City-Scooter-Mapper) project the author made before.

On **AWS serverless** infrastructure (provisioned by **Terraform**), the program runs an **ELT** pipeline with **Lambda** images in **ECR**, triggered by **EventBridge**. Raw data is stored in **S3**, then aggregated into **DynamoDB** for low-latency real-time queries and into **Parquet (S3/Athena)** for historical analysis. Aggregated snapshots are compacted into hourly Parquet files to improve read efficiency and reduce Athena scan overhead. **API Gateway** and **CloudFront** serve the application. **IAM roles** and scoped resource permissions enforce secure access.

Observability is implemented through **CloudWatch dashboards** covering Lambda invocations, errors, duration, and API Gateway access logs, alongside **alarms** with optional email notifications. The project also includes **CI workflow checks** and **API/aggregation tests** to maintain code quality and deployment reliability.<br><br>

<figure>
  <img width="1900" height="751" alt="Screenshot 2026-03-11 122905" src="https://github.com/user-attachments/assets/44b9724f-8b03-4474-b7a8-db77e0d05607" >
  <figcaption><em>Figure 1. CloudWatch dashboard overview</em></figcaption>
</figure>


## ✨ What's New

| Original Scooter Mapper Project | AWS Serverless Evolution | Data Model / Design Impact |
|---|---|---|
| Docker Compose | Serverless AWS Infrastructure | From self-managed containers to managed event-driven services with minimum cost |
| ETL pipeline | ELT pipeline | Raw source snapshots are stored as immutable JSON in S3 before transformation, improving loading speed and traceability |
| Kafka topics for data transport | EventBridge scheduler + Lambda async invocation | From async, decoupled stream topic model to function-trigger async and loose-coupled model. With less infra to manage, Lambda can be faster at low traffic, but Kafka might perform better for high throughput as it has horizontal scalability with multi- partition/consumer option for ingest-transform process |
| DuckDB tables | S3 raw snapshots -> DynamoDB current snapshot + S3 parquet history queried by Athena | Split data into NoSQL database for low-latency current-state key queries (DynamoDB), and columnar formatted parquet for fast light-weight historical analytics (S3/Athena) without the need to maintain a data warehouse |
| NA | IAM roles/policies + API Gateway-managed entrypoint | Assign terraform IAM user for it to deploy roles/resources, each Lambda assumes least-privilege IAM role, and invocation/image access is granted via restricted resource permissions |
| Containerized frontend/backend | Frontend on S3+CloudFront, Lambda images in ECR | Deliver website with high performance and low latency; ECR supports large deployment sizes, allowing heavy dependencies |
| NA | GitHub Actions CI for Ruff, ESLint, and Terraform format checks | Add schema/style quality checks at PR time, reducing integration drift across Python, frontend, and Terraform |
| NA | CloudWatch dashboards + alarms (SNS email optional) | Add runtime visibility for `Lambda invocations/errors/p95 duration` and `API Gateway access logs`, with threshold-based `email alerting` for failures and latency |


## AWS Serverless Deployment with Terraform

## 🔐 Security architecture

```text
terraform-admin (IAM User) + Access Key
            ↓
        terraform apply
            ↓ creates
---------------------------------
aws_iam_role.ingest
aws_iam_role.transform
aws_iam_role.api
aws_iam_role.compact
aws_ecr_repository.ingest
aws_ecr_repository.transform
aws_ecr_repository.api
aws_ecr_repository.compact
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

## 🛠️ Setup

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

If you want to receive alarm emails, set `alarm_email_endpoint` in `terraform.tfvars` to your email address. Leave it commented out to disable email notifications.

### 1) Create ECR Repositories

```bash
cd terraform
terraform init

# ecr repo only needs to be created once unless running terraform destroy
terraform apply -target=aws_ecr_repository.ingest -target=aws_ecr_repository.transform -target=aws_ecr_repository.api -target=aws_ecr_repository.compact
```

### 2) Build and Push Lambda Images to ECR

Make sure Docker is running on the background and run the commands below:

```bash
chmod +x scripts/build_and_push_to_ecr.sh
./scripts/build_and_push_to_ecr.sh latest
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

## 🌐 API Endpoints

- /api/heatmap
- /api/heatmap/geojson
- /api/stats
- /api/health

## 🧮 Athena Query Example

An Athena named query example is provided in [terraform/athena.tf](terraform/athena.tf). The hourly_hexagon_avg query demonstrates how to analyze hourly averaged scooter availability over time for a selected H3 hexagon.

## 🔎 Tests

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

## 🚀 Future Improvements

- Add CloudWatch dashboards, structured logs, and alarms (Lambda errors, latency, and EventBridge failures) to increase observability.
- Ingest additional GBFS providers/cities and standardize them into a unified model.
- Add data quality checks (e.g. anomaly detection) in the pipeline.
- Load data to Redshift for more regular analytical tasks.
- Expand CI/CD from linting to automated image build/deploy and Terraform plan checks.
- Improve cost controls with retention cleanup and lifecycle policies, etc.

---

**Built for Portfolio Demonstration** | Ping | 2026

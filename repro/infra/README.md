# Terraform for the BigQuery grants reproduction

This configuration creates a dedicated dataset and two service accounts.

| Resource | Purpose |
| --- | --- |
| `dbt-bq-location-runner` | dbt v1 and v2 impersonate this account. It has Data Editor (WRITER) and the TableIamPolicySetter custom role only on the dedicated dataset, plus Job User and Read Session User on the data and execution projects. |
| `dbt-bq-location-reader` | Receives table-level Data Viewer from dbt. Terraform gives it Job User for test queries, but no dataset- or project-level Data Viewer. |
| `dbt_bq_location_repro` | Isolated dataset, separate from datasets managed by other Terraform states. |

The configured `impersonator_member` can impersonate both accounts. The BigQuery, BigQuery Storage, IAM, and IAM Credentials APIs should already be enabled in the selected projects. Terraform does not manage those API settings.

## Apply manually

From the repository root:

```sh
cd repro/infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project IDs and impersonator member.
terraform init
terraform plan
terraform apply
```

Review the plan before applying. This creates cloud resources and IAM bindings. The dataset has Terraform deletion protection enabled.

Export the resulting values in the same shell, then return to the dbt project root:

```sh
export DBT_PROJECT_ID="$(terraform output -raw data_project_id)"
export DBT_EXECUTION_PROJECT_ID="$(terraform output -raw execution_project_id)"
export DBT_DATASET_ID="$(terraform output -raw dataset_id)"
export DBT_LOCATION="$(terraform output -raw dataset_location)"
export DBT_IMPERSONATE_SERVICE_ACCOUNT="$(terraform output -raw runner_service_account_email)"
export DBT_GRANTEE="$(terraform output -raw grantee_member)"
export DBT_GRANTEE_EMAIL="$(terraform output -raw grantee_service_account_email)"
cd ../..
```

Follow [the v1/v2 comparison procedure](../doc/verification.md). Use the same runner account and dataset for each dbt version. For the optional real grant test, keep `DBT_GRANTEE` set to the reader account.

The custom role contains only `bigquery.tables.setIamPolicy` and is bound to the dedicated dataset. Together with dataset WRITER, it lets the runner perform the optional real table grant test. After running the model successfully, verify that the reader can query the table:

```sh
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="$DBT_GRANTEE_EMAIL" \
bq --project_id="$DBT_EXECUTION_PROJECT_ID" query --use_legacy_sql=false \
  "SELECT id FROM \`$DBT_PROJECT_ID.$DBT_DATASET_ID.grant_probe\`"
```

The `bq` check runs a BigQuery job and should return `42` after dbt grants table access. The reader receives no access to other tables in the dataset from this configuration.

`terraform.tfvars`, state files, and `.terraform/` are ignored by Git. Commit the generated `.terraform.lock.hcl` alongside the Terraform configuration.

resource "google_project_iam_custom_role" "table_iam_policy_setter" {
  project     = var.data_project_id
  role_id     = "TableIamPolicySetter"
  title       = "Table IAM Policy Setter"
  description = "Allows dbt to update IAM policies on tables in the reproduction dataset."
  permissions = ["bigquery.tables.setIamPolicy"]
}

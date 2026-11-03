resource "google_service_account" "runner" {
  project      = var.data_project_id
  account_id   = "dbt-bq-location-runner"
  display_name = "dbt BigQuery location repro runner"
  description  = "Runs the same dbt project under v1 and v2."
}

# dbt grants table-level Data Viewer to this account during the test.
# Terraform does not grant it dataset- or project-level Data Viewer.
resource "google_service_account" "grantee" {
  project      = var.data_project_id
  account_id   = "dbt-bq-location-reader"
  display_name = "dbt BigQuery location repro grantee"
  description  = "Receives table-level Data Viewer through dbt grants."
}

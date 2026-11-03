resource "google_bigquery_dataset_iam_member" "runner_data_editor" {
  project    = var.data_project_id
  dataset_id = google_bigquery_dataset.repro.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.runner.member
}

resource "google_bigquery_dataset_iam_member" "runner_table_iam_policy_setter" {
  project    = var.data_project_id
  dataset_id = google_bigquery_dataset.repro.dataset_id
  role       = google_project_iam_custom_role.table_iam_policy_setter.name
  member     = google_service_account.runner.member
}

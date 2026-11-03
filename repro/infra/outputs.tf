output "data_project_id" {
  value = var.data_project_id
}

output "execution_project_id" {
  value = var.execution_project_id
}

output "dataset_id" {
  value = google_bigquery_dataset.repro.dataset_id
}

output "dataset_location" {
  value = google_bigquery_dataset.repro.location
}

output "runner_service_account_email" {
  value = google_service_account.runner.email
}

output "grantee_service_account_email" {
  value = google_service_account.grantee.email
}

output "grantee_member" {
  value = google_service_account.grantee.member
}

output "table_iam_policy_setter_role" {
  value = google_project_iam_custom_role.table_iam_policy_setter.name
}

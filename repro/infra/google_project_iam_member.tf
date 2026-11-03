resource "google_project_iam_member" "runner_job_user" {
  for_each = toset([var.data_project_id, var.execution_project_id])

  project = each.value
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.runner.member
}

resource "google_project_iam_member" "runner_read_session_user" {
  for_each = toset([var.data_project_id, var.execution_project_id])

  project = each.value
  role    = "roles/bigquery.readSessionUser"
  member  = google_service_account.runner.member
}

resource "google_project_iam_member" "grantee_job_user" {
  project = var.execution_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.grantee.member
}

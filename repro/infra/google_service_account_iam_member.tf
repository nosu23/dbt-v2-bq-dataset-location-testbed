resource "google_service_account_iam_member" "runner_impersonator" {
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.impersonator_member
}

resource "google_service_account_iam_member" "grantee_impersonator" {
  service_account_id = google_service_account.grantee.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.impersonator_member
}

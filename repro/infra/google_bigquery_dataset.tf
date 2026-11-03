resource "google_bigquery_dataset" "repro" {
  project         = var.data_project_id
  dataset_id      = "dbt_bq_location_repro"
  location        = var.location
  description     = "Dedicated dataset for comparing dbt v1 and v2 BigQuery grants."
  deletion_policy = "PREVENT"
}

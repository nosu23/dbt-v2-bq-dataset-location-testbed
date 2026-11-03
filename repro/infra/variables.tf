variable "data_project_id" {
  description = "Project that owns the dedicated BigQuery dataset and service accounts."
  type        = string
}

variable "execution_project_id" {
  description = "Project used to run BigQuery jobs."
  type        = string
}

variable "impersonator_member" {
  description = "IAM member allowed to impersonate both test service accounts, for example user:you@example.com."
  type        = string

  validation {
    condition = anytrue([
      startswith(var.impersonator_member, "user:"),
      startswith(var.impersonator_member, "serviceAccount:"),
    ])
    error_message = "impersonator_member must start with user: or serviceAccount:."
  }
}

variable "location" {
  description = "Location of the dedicated BigQuery dataset."
  type        = string
  default     = "US"
}

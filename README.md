# BigQuery dataset location testbed for dbt v1 and v2

This dbt project compares the BigQuery dataset location lookup used by `grants` in dbt Core v1, unpatched dbt v2, and patched dbt v2. All three use the same profile, macro, dataset, and impersonated service account.

See [doc/verification.md](repro/doc/verification.md) for setup, commands, expected observations, and a PR evidence checklist. Expected observations are not test results; run the commands and record the actual output before citing them in a PR.

The main check uses `run-operation probe_grants_location`. It performs the location lookup and prints the SQL for checking table grants, without changing IAM. An optional `grant_probe` model exercises a real table-level grant.

Infrastructure for the isolated dataset and two test service accounts is in [repro/infra](repro/infra/README.md). Terraform commands are run manually.

# BigQuery dataset location testbed for dbt v1 and v2

This dbt project reproduces a BigQuery dataset location permission error in dbt v2 and verifies a proposed fix. The same `grant_probe` model, profile, dataset, runner service account, and table-level `grants` configuration are used for each run.

| Build | Observed result |
| --- | --- |
| dbt Core 1.12.6 + dbt-bigquery 1.12.1 | Model succeeds; the grantee service account can read `id=42` |
| Unpatched dbt v2.0.9 | Model fails with a 403 on project-wide `INFORMATION_SCHEMA.SCHEMATA` |
| Patched dbt OSS v2.0.8 + patched BigQuery ADBC Go driver | Model succeeds; the grantee service account can read `id=42` |

See [the verification guide](repro/doc/verification.md) for setup, commands, IAM reset steps, exact observations, and build details. The unpatched public release and the patched source build have different version numbers; record both when citing these results.

Infrastructure for the isolated dataset and two test service accounts is in [repro/infra](repro/infra/README.md). Terraform commands are run manually.

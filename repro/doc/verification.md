# BigQuery dataset location testbed for dbt v1 and v2

This project runs the same BigQuery grants-path lookup with dbt Core v1 + dbt-bigquery and dbt v2. The intended comparison is:

| Build | Dataset location lookup | Outcome to check |
| --- | --- | --- |
| dbt v1 | BigQuery dataset metadata (`get_dataset`) | Location lookup succeeds with dataset-scoped access |
| dbt v2, unpatched | Project-wide `INFORMATION_SCHEMA.SCHEMATA` | May fail with `bigquery.datasets.get` when the service account has access only to the target dataset |
| dbt v2, patched | Dataset metadata through the patched BigQuery ADBC driver | Location lookup succeeds with the same service account |

These are expected results from the implementations, **not test results**. Record actual outputs before using them as PR evidence.

## Prerequisites

To provision an isolated dataset and service accounts, follow [the Terraform setup](../infra/README.md) first. The runner service account executes dbt; the reader service account is the table-level grant target.

- A BigQuery dataset and a service account with access to that dataset.
- BigQuery Job User on the execution project, any driver-specific read permissions needed for dbt v2, and local permission to impersonate the service account.
- A dbt Core v1 executable with dbt-bigquery installed, an unpatched dbt v2 executable, and a patched dbt v2 executable with its matching patched BigQuery ADBC Go driver.

The same `dbt_project.yml`, `profiles/profiles.yml`, model, and macro are used for all three runs. Project IDs and account names are supplied through environment variables.

From this repository's root, set the same connection values for every run:

```sh
export DBT_PROJECT_ID="<data-project-id>"
export DBT_EXECUTION_PROJECT_ID="<execution-project-id>"
export DBT_DATASET_ID="<existing-dataset-id>"
export DBT_IMPERSONATE_SERVICE_ACCOUNT="<service-account-email>"
export DBT_LOCATION="US"
```

The data project owns the dataset; the execution project runs BigQuery jobs. They may be the same project. `DBT_DATASET_ID` is the **existing dataset's exact name**; this project does not add a custom schema suffix.

## Compare the location lookup used by grants

`probe_grants_location` constructs a table relation and invokes BigQuery's `get_show_grant_sql` macro. That macro calls `adapter.get_dataset_location` before constructing the `INFORMATION_SCHEMA.OBJECT_PRIVILEGES` query. The probe prints that query. It does not execute the privileges query or change table IAM, and the `grant_probe` table does not need to exist. The location lookup itself does contact BigQuery.

### 1. dbt v1

```sh
export DBT_BIN="/absolute/path/to/dbt-v1"
unset ADBC_REPOSITORY DISABLE_CDN_DRIVER_CACHE DISABLE_AUTO_DRIVER_REBUILD
"$DBT_BIN" --version
"$DBT_BIN" run-operation probe_grants_location --profiles-dir profiles
```

Confirm that this is dbt Core v1 with dbt-bigquery installed. A successful lookup should print SQL containing `region-US.INFORMATION_SCHEMA.OBJECT_PRIVILEGES` (or the dataset's actual region).

### 2. Unpatched dbt v2

```sh
export DBT_BIN="/absolute/path/to/unpatched-dbt-v2"
unset ADBC_REPOSITORY DISABLE_CDN_DRIVER_CACHE DISABLE_AUTO_DRIVER_REBUILD
"$DBT_BIN" --version
"$DBT_BIN" run-operation probe_grants_location --profiles-dir profiles
```

With a service account restricted to the target dataset, check whether this fails while querying project-wide `INFORMATION_SCHEMA.SCHEMATA`. Keep the exact error for the PR.

### 3. Patched dbt v2 and Go driver

```sh
export DBT_BIN="/absolute/path/to/patched-dbt-v2"
export ADBC_REPOSITORY="/absolute/path/to/patched-arrow-adbc/go/adbc/pkg"
export DISABLE_CDN_DRIVER_CACHE=true
export DISABLE_AUTO_DRIVER_REBUILD=true
"$DBT_BIN" --version
"$DBT_BIN" run-operation probe_grants_location --profiles-dir profiles
```

Confirm that `ADBC_REPOSITORY` contains the patched `libadbc_driver_bigquery` shared library. Compare the printed SQL with the v1 run. Keep the build revisions and sanitized command output with your PR evidence.

## Optional: exercise an actual table grant

The Terraform setup grants the runner dataset WRITER (Data Editor) and a dataset-scoped custom role containing only `bigquery.tables.setIamPolicy`. This lets the same runner perform both the location probe and the optional real table grant test.

`models/grant_probe.sql` creates a table and grants `roles/bigquery.dataViewer` **on that table** to `DBT_GRANTEE`. Set a valid principal such as `user:someone@example.com` or `serviceAccount:account@project.iam.gserviceaccount.com`:

```sh
export DBT_GRANTEE="<principal>"
"$DBT_BIN" run --profiles-dir profiles --select grant_probe
"$DBT_BIN" run --profiles-dir profiles --select grant_probe
```

Run this separately with each dbt build only if the impersonated service account can update the table IAM policy. The first run creates the table; the second run can compare existing grants and call `get_dataset_location`. These runs execute BigQuery jobs and change table IAM. Dataset `WRITER` alone is insufficient for the grant; the custom role supplies the missing permission. If `DBT_GRANTEE` is empty, the model has no grants; use the probe above for the location comparison.

A successful probe proves the **location lookup** works. A successful model run with `DBT_GRANTEE` also checks the **end-to-end grant workflow**.

## References

- [dbt grants configuration](https://docs.getdbt.com/reference/resource-configs/grants?version=2)
- [BigQuery table grants and IAM](https://cloud.google.com/bigquery/docs/control-access-to-resources-iam)

## Record results for the PR

Run the three probe commands from this repository root with the same `DBT_PROJECT_ID`, `DBT_EXECUTION_PROJECT_ID`, `DBT_DATASET_ID`, `DBT_IMPERSONATE_SERVICE_ACCOUNT`, and `DBT_LOCATION`. For each run, record:

| Item | v1 | v2 unpatched | v2 patched |
| --- | --- | --- | --- |
| dbt version / commit | | | |
| BigQuery driver version / commit | | | |
| Exit status | | | |
| Printed `OBJECT_PRIVILEGES` SQL or exact error | | | |
| BigQuery job ID, if a job was created | | | |

Record whether the v1 and patched v2 runs print the same region-qualified `OBJECT_PRIVILEGES` reference, and whether unpatched v2 fails specifically at project-wide `INFORMATION_SCHEMA.SCHEMATA`. If any result differs, keep the actual output and investigate before describing it as a regression or fix. Redact personal account details and tokens before attaching output to a public PR.

The probe's success establishes the dataset **location lookup** behavior. To claim that an actual table grant also succeeds in v1 or patched v2, separately run the optional model test with a service account that has table IAM update permission.

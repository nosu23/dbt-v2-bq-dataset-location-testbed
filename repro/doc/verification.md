# Verify BigQuery dataset location lookup during dbt grants

This project runs the same table model under dbt v1, unpatched dbt v2, and patched dbt v2 with a patched BigQuery ADBC Go driver. `models/grant_probe.sql` selects `42 as id`; `models/schema.yml` grants `roles/bigquery.dataViewer` **on that table** to the service account named by `DBT_GRANTEE`.

The runner service account can write to the target dataset and update table IAM. It does not have the project-wide dataset metadata access required by the unpatched v2 lookup. The grantee service account is the recipient of the table grant and is used only to verify the resulting access.

## Set up

Provision the dataset and service accounts with [the Terraform configuration](../infra/README.md). From this repository's root, load its outputs into the shell:

```sh
export TESTBED_DIR="$(pwd)"
export DBT_PROJECT_ID="$(terraform -chdir=repro/infra output -raw data_project_id)"
export DBT_EXECUTION_PROJECT_ID="$(terraform -chdir=repro/infra output -raw execution_project_id)"
export DBT_DATASET_ID="$(terraform -chdir=repro/infra output -raw dataset_id)"
export DBT_LOCATION="$(terraform -chdir=repro/infra output -raw dataset_location)"
export DBT_IMPERSONATE_SERVICE_ACCOUNT="$(terraform -chdir=repro/infra output -raw runner_service_account_email)"
export DBT_GRANTEE="$(terraform -chdir=repro/infra output -raw grantee_member)"
export DBT_GRANTEE_EMAIL="$(terraform -chdir=repro/infra output -raw grantee_service_account_email)"
```

The data project owns the dataset; the execution project runs BigQuery jobs. `DBT_DATASET_ID` must be the existing dataset's exact name. The `DBT_GRANTEE` value includes the `serviceAccount:` prefix, whereas `DBT_GRANTEE_EMAIL` does not.

The observed run used separate data and execution projects, a dataset in `US`, and separate runner and grantee service accounts. The `grants` model runs BigQuery jobs and changes table IAM.

## Compare the three builds

### 1. dbt v1

```sh
uv sync --locked --python 3.13
uv run --locked dbt --version
uv run --locked dbt run --profiles-dir profiles --select grant_probe
```

`pyproject.toml` and `uv.lock` pin dbt Core 1.12.6 and dbt-bigquery 1.12.1. The observed run completed successfully (`PASS=1`, `ERROR=0`) and created a one-row table. Verify that the grantee can read it using the query under [Check table access](#check-table-access).

### 2. Reset the table grant

The v1 run gives the grantee table access. Remove only that table-level binding before testing unpatched v2. Impersonate the runner service account, which has permission to manage table IAM:

```sh
export TABLE_ID="${DBT_PROJECT_ID}:${DBT_DATASET_ID}.grant_probe"
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="$DBT_IMPERSONATE_SERVICE_ACCOUNT" \
  bq get-iam-policy --table=true "$TABLE_ID"
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="$DBT_IMPERSONATE_SERVICE_ACCOUNT" \
  bq remove-iam-policy-binding \
    --member="$DBT_GRANTEE" \
    --role=roles/bigquery.dataViewer \
    --table=true "$TABLE_ID"
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="$DBT_IMPERSONATE_SERVICE_ACCOUNT" \
  bq get-iam-policy --table=true "$TABLE_ID"
```

In the observed run, the policy initially contained the grantee's Data Viewer binding and contained no bindings afterward. A SELECT as the grantee later failed with a table permission error. A SELECT immediately after revocation still succeeded once; the reason was not established, so verify the denied SELECT before treating the reset as complete.

### 3. Unpatched dbt v2

Run the public dbt v2 binary without local-driver overrides:

```sh
unset ADBC_REPOSITORY DISABLE_CDN_DRIVER_CACHE DISABLE_AUTO_DRIVER_REBUILD
dbt --version
dbt run --profiles-dir profiles --select grant_probe
```

The observed public binary reported `dbt 2.0.9`. Two runs failed with the same error:

```text
[DbDriverFailed (dbt1308)]: [BigQuery] googleapi: Error 403:
Access Denied: Table <data-project-id>:INFORMATION_SCHEMA.SCHEMATA:
User does not have the required permissions ('bigquery.datasets.get' permission(s)
at the dataset level) to query system entity <data-project-id>:INFORMATION_SCHEMA.SCHEMATA.
```

### 4. Patched dbt v2 and BigQuery ADBC Go driver

The tested dbt fork was `nosu23/dbt`, branch `fix/bigquery-dataset-location`, commit `6bc56d02d`. The driver fork was `nosu23/arrow-adbc`, branch `nosu23/bigquery/get-dataset-metadata`, commit `274c5df6`.

Build the BigQuery driver on macOS. With Go 1.27.3 and the dependencies used by this checkout, `http2legacy` was needed to compile gRPC; `GIT_VERSION=unknown` avoided a Makefile Git-tag lookup error:

```sh
export ADBC_SOURCE_DIR="<path-to-your-arrow-adbc-checkout>"
export DBT_SOURCE_DIR="<path-to-your-dbt-checkout>"

cd "$ADBC_SOURCE_DIR/go/adbc/pkg"
mise exec go@1.27.3 -- make \
  GIT_VERSION=unknown \
  BUILD_TAGS=driverlib,netgo,http2legacy \
  libadbc_driver_bigquery.dylib

cd "$DBT_SOURCE_DIR"
cargo build -p dbt-sa-cli --bin dbt
```

Return to this testbed's root. Set `ADBC_REPOSITORY` to the directory containing the newly built `.dylib` and run the patched binary by absolute path:

```sh
cd "$TESTBED_DIR"
export ADBC_REPOSITORY="$ADBC_SOURCE_DIR/go/adbc/pkg"
export DISABLE_CDN_DRIVER_CACHE=true
export DISABLE_AUTO_DRIVER_REBUILD=true
"$DBT_SOURCE_DIR/target/debug/dbt" --version
"$DBT_SOURCE_DIR/target/debug/dbt" \
  run --profiles-dir profiles --select grant_probe
```

The tested binary reported `dbt-oss 2.0.8`. Its log confirmed `BigQuery ADBC driver is being loaded from <ADBC_REPOSITORY> in debug mode.` The model succeeded, and the run finished successfully with one model processed. The public binary (`dbt 2.0.9`) and patched source build (`dbt-oss 2.0.8`) have different version numbers; include both versions and commits in PR evidence.

## Check table access

Run this as the grantee after v1 or patched v2. After resetting the table grant, use the same command to confirm access is denied. `--nouse_cache` avoids a cached query result.

```sh
QUERY_SQL="SELECT id FROM \`${DBT_PROJECT_ID}.${DBT_DATASET_ID}.grant_probe\`"
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="$DBT_GRANTEE_EMAIL" \
  bq --project_id="$DBT_EXECUTION_PROJECT_ID" query \
    --use_legacy_sql=false --nouse_cache "$QUERY_SQL"
```

The observed v1 and patched-v2 checks both returned `42`. After the grant reset had taken effect, the same query failed with a table permission error.

## Evidence and remaining work

This end-to-end `dbt run` comparison confirms model execution and table grant behavior. The earlier `probe_grants_location` helper macro was removed; no `run-operation` is needed. The exact internal call that first reaches `get_dataset_location` in the unpatched run has not been isolated. Targeted Go and Rust tests, upstream Issue, and upstream PRs remain separate tasks.

Before posting new logs publicly, replace project IDs, service account addresses, and local paths with placeholders while retaining the versions, relevant error text, and local-driver load confirmation.

## References

- [dbt grants configuration](https://docs.getdbt.com/reference/resource-configs/grants?version=2)
- [BigQuery table grants and IAM](https://cloud.google.com/bigquery/docs/control-access-to-resources-iam)

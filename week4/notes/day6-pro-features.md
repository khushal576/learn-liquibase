# Week 4, Day 6 — Liquibase Pro Features Overview

## No New Changelog Today
Day 6 surveys Liquibase Pro. These features require a Pro license — everything before this week works in Community (free).

---

## Liquibase Community vs Pro

| Feature | Community | Pro |
|---------|-----------|-----|
| Core migration (update, rollback, diff) | Yes | Yes |
| All change types | Yes | Yes |
| CLI, Maven, Gradle | Yes | Yes |
| Stored Logic (views, functions, procedures) | Limited | Full |
| **Flow Files** | Basic (4.24+) | Full |
| **Quality Checks** | No | Yes |
| **Drift Detection** | No | Yes |
| **Structured Logging** | No | Yes |
| **Policy Checks** | No | Yes |
| **Rollback with data** | No | Yes |
| **Change Reports** | No | Yes |

---

## Flow Files (Community 4.24+, Full in Pro)

Flow files define a reusable pipeline of Liquibase commands. Replaces shell scripts.

```yaml
# liquibase.flowfile.yaml
stages:
  validate:
    actions:
      - type: liquibase
        command: validate
      - type: liquibase
        command: status
        cmdArgs:
          verbose: true

  preview:
    actions:
      - type: liquibase
        command: updateSQL
        cmdArgs:
          output-file: ${OUTPUT_DIR}/migration-preview-${DEPLOY_ID}.sql

  deploy:
    actions:
      - type: liquibase
        command: tag
        cmdArgs: { tag: "pre-deploy-${DEPLOY_ID}" }
      - type: liquibase
        command: update
        cmdArgs:
          contexts: ${DEPLOY_CONTEXTS}

globalVariables:
  OUTPUT_DIR: ./build/liquibase
  DEPLOY_ID: ${DEPLOY_ID}
  DEPLOY_CONTEXTS: ${CONTEXTS:dev}
```

Run:
```bash
liquibase flow --flow-file=liquibase.flowfile.yaml
```

---

## Quality Checks (Pro)

Automated rules that scan your changelogs and flag violations before deployment.

Built-in checks include:

| Check | What It Catches |
|-------|----------------|
| `SqlGrantAdminOption` | Dangerous GRANT WITH ADMIN OPTION |
| `SqlGrantOptionGranted` | Dangerous GRANT WITH GRANT OPTION |
| `WarnOnUseDatabase` | Hardcoded USE DATABASE in changelogs |
| `TableNameMustBeUppercase` | Naming convention violations |
| `PrimaryKeyOnCreateTable` | Tables created without a primary key |
| `RequireChangeSetDisRunOnChangeOrRunAlways` | Changesets without explicit behavior |
| `ChangesetCommentCheck` | Missing comments on changesets |

Run checks:
```bash
# Run all checks
liquibase checks run --changelog-file=master.xml

# List all available checks
liquibase checks show

# Enable/configure a check
liquibase checks enable --check-name=TableNameMustBeUppercase
liquibase checks customize --check-name=TableNameMustBeUppercase
```

In CI pipeline:
```yaml
- name: Run quality checks
  run: liquibase checks run --changelog-file=master.xml --auto-update=OFF
  # Fails the pipeline if any check fails
```

---

## Drift Detection (Pro)

Detects when a database has been modified outside of Liquibase (manual changes, direct DDL).

```bash
# Compare the live database to what your changelogs expect
liquibase drift detect --changelog-file=master.xml

# Generate a report
liquibase drift detect --format=html --output-file=drift-report.html
```

Output shows:
- Tables that exist in the DB but not in any changelog
- Columns that were manually added/removed
- Indexes not tracked by Liquibase
- Constraints that differ from the changelog

Use case: run weekly as a cron job to catch unauthorized manual changes in production.

---

## Structured Logging (Pro)

Pro emits JSON-formatted logs for integration with observability platforms:

```bash
liquibase update --log-format=JSON
```

JSON output:
```json
{
  "timestamp": "2024-06-15T10:23:45.123Z",
  "level": "INFO",
  "changeSet": {
    "id": "w4-day2-001",
    "author": "khushal",
    "filename": "week4/changelogs/day2-preconditions.xml"
  },
  "message": "ChangeSet week4/changelogs/day2-preconditions.xml::w4-day2-001::khushal ran successfully"
}
```

Ingest into: Datadog, Splunk, Elasticsearch, CloudWatch, etc.

---

## Policy Checks (Pro)

Custom checks written in Python that enforce company-specific rules:

```python
# check_no_drop_in_prod.py
import liquibase_checks

def check(change_set, ctx):
    if ctx.contexts and 'prod' in ctx.contexts:
        for change in change_set.changes:
            if change.change_type in ['dropTable', 'dropColumn']:
                raise liquibase_checks.CheckFailed(
                    f"DROP operations not allowed with prod context: {change.change_type}"
                )
```

Register:
```bash
liquibase checks create --check-name=NoDropInProd --package-name=check_no_drop_in_prod
```

---

## Change Reports (Pro)

Auto-generated HTML reports showing what changed, when, and by whom:

```bash
liquibase update --report-enabled=true --report-path=./reports/
```

Reports include:
- List of all changesets applied
- SQL executed
- Execution times
- Success/failure status
- Tag information

Useful for: audit requirements, compliance, release notes.

---

## Should You Use Pro?

For learning and most projects: **Community is enough.** Pro becomes valuable when:

- You have compliance requirements (audit reports, policy enforcement)
- Teams of 10+ developers contributing changelogs (quality checks catch issues early)
- You're seeing schema drift and need automated detection
- Your CI/CD needs structured, machine-readable migration logs

---

## Key Takeaways

- Community edition covers 95% of use cases — everything in this course works without Pro
- Flow files: structured pipelines replacing shell scripts (partially in Community 4.24+)
- Quality checks: automated linting of changelogs (Pro) — catches missing PKs, naming violations
- Drift detection: catches manual changes in production (Pro) — run weekly as a cron job
- Structured logging: JSON logs for observability platforms (Pro)
- Policy checks: custom Python rules for company-specific standards (Pro)

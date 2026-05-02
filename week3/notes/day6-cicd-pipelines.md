# Week 3, Day 6 — CI/CD Pipeline Files Deep Dive

## Hands-On Files
Open: `week3/ci/github-actions.yml`
Open: `week3/ci/gitlab-ci.yml`

---

## Pipeline Structure Overview

Both pipelines follow the same pattern:

```
PR / Merge Request:
  validate → syntax check
  validate → futureRollbackSQL (verify rollback plans)
  validate → updateSQL (generate preview artifact)

Merge to main:
  tag → update → (smoke test) → rollback on failure
```

---

## GitHub Actions — Key Concepts

### Service Containers
The Postgres database runs as a service container alongside your job:
```yaml
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_USER: liquibase
      POSTGRES_PASSWORD: liquibase123
      POSTGRES_DB: learndb
    options: >-
      --health-cmd pg_isready
      --health-interval 5s
      --health-retries 5
```
The `options` block waits for Postgres to be healthy before the job steps start.

### Uploading SQL Preview as Artifact
```yaml
- name: Upload SQL preview as artifact
  uses: actions/upload-artifact@v4
  with:
    name: migration-sql-preview
    path: migration-preview.sql
    retention-days: 30
```
This makes the SQL preview downloadable from the Actions run page — useful for DBA review.

### Conditional Rollback Step
```yaml
- name: Rollback on migration failure
  if: failure() && steps.migrate.outcome == 'failure'
```
This step only runs if the migration step itself failed. It won't run if a later step (like smoke tests) fails — be careful with the condition.

---

## GitLab CI — Key Concepts

### `when: manual` for Rollback
```yaml
rollback-production:
  when: manual
```
The rollback job exists in the pipeline but must be triggered by a human in the GitLab UI. This is the correct pattern — you never want automated rollbacks in production without human decision.

### Artifacts
```yaml
artifacts:
  paths:
    - rollback-preview.sql
  expire_in: 7 days
```
GitLab stores the SQL preview file and makes it downloadable from the pipeline page.

### Reusable Templates
```yaml
.liquibase_base:    # .prefix = hidden job (template, not executed)
  image: $LIQUIBASE_IMAGE
  before_script:
    - echo "Connecting to $DB_URL"
```
Jobs that `extends: .liquibase_base` inherit its configuration.

---

## Secrets and Credentials

**Never** put database credentials in `gitlab-ci.yml` or `github-actions.yml`.

### GitHub Actions
Store in: `Settings → Secrets and variables → Actions`
```yaml
env:
  DB_URL: ${{ secrets.DB_URL }}
  DB_USER: ${{ secrets.DB_USER }}
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

### GitLab CI
Store in: `Settings → CI/CD → Variables` (mask them)
```yaml
script:
  - liquibase --url=$DB_URL --username=$DB_USER --password=$DB_PASSWORD ...
```
GitLab automatically masks protected variables in job logs.

---

## Per-Environment Configuration

Use different variable groups per environment:

```yaml
# GitHub Actions: use environments
migrate-staging:
  environment: staging    # uses staging secrets

migrate-production:
  environment: production # uses production secrets (requires approval)
```

```yaml
# GitLab CI: use environment-scoped variables
# Set DB_URL for environment "production" in Settings → CI/CD → Variables
migrate-production:
  environment:
    name: production
```

---

## The Approval Gate for Production

In GitHub Actions, set up an environment protection rule:
- `Settings → Environments → production → Required reviewers`
- Any job with `environment: production` will pause and wait for a human to approve

This means migrations never run in production without a manual "go ahead."

---

## What to Put in `liquibase.properties` vs CI Variables

| Setting | Where |
|---------|-------|
| `changeLogFile` | `liquibase.properties` (commit to Git) |
| `driver` | `liquibase.properties` (commit to Git) |
| `logLevel` | `liquibase.properties` (commit to Git) |
| `url` | CI/CD secret variable |
| `username` | CI/CD secret variable |
| `password` | CI/CD secret variable |
| `contexts` | CI/CD pipeline step (varies by env) |

---

## Key Takeaways

- Gate every PR with: `validate` + `futureRollbackSQL` + `updateSQL` artifact
- Production deploys: tag → migrate → rollback on failure
- Use `when: manual` for rollback jobs — never auto-rollback production
- All secrets go in CI/CD secret management — never in committed files
- Use environment protection rules to require approval before production migrations
- Upload SQL preview as an artifact — it becomes part of the deployment audit trail

# Week 3, Day 5 — CI/CD Integration

## Hands-On Files
Open: `week3/ci/github-actions.yml`
Open: `week3/ci/gitlab-ci.yml`

---

## Why Automate Liquibase in CI/CD?

Manual migration runs are error-prone:
- Someone forgets to run migrations after a deploy
- Migrations run in the wrong order across environments
- No audit trail of when and by whom migrations ran

Automating Liquibase in CI/CD means:
- Migrations always run before the new application code starts
- Failed migrations block the deploy — preventing broken deployments
- Every migration is logged and auditable

---

## The Standard CI/CD Pipeline Stage Order

```
1. Run tests (unit + integration)
2. Build application artifact
3. Run liquibase validate        ← syntax check
4. Run liquibase futureRollbackSQL  ← verify rollback plans
5. Run liquibase updateSQL       ← generate SQL artifact for review
6. Deploy application
7. Run liquibase update          ← apply migrations
8. Run smoke tests
```

Migrations run AFTER deploy but BEFORE traffic is switched to new pods (in rolling deployments).

---

## GitHub Actions Workflow

See: `week3/ci/github-actions.yml`

Key steps in the workflow:
- Spins up Postgres as a service container
- Validates changelog syntax on every PR
- Runs `futureRollbackSQL` to verify rollbacks
- On merge to main: runs `liquibase update`

---

## GitLab CI Pipeline

See: `week3/ci/gitlab-ci.yml`

---

## Environment-Specific Configuration

Never hardcode credentials. Use environment variables:

```bash
# liquibase.properties (committed to Git — no secrets)
changeLogFile=db/changelog/master.xml
driver=org.postgresql.Driver
logLevel=INFO

# Runtime environment variables (set in CI/CD secrets)
# LIQUIBASE_COMMAND_URL
# LIQUIBASE_COMMAND_USERNAME
# LIQUIBASE_COMMAND_PASSWORD
```

Liquibase reads `LIQUIBASE_COMMAND_*` environment variables automatically and overrides the properties file values.

```bash
# In CI pipeline:
export LIQUIBASE_COMMAND_URL=jdbc:postgresql://prod-db:5432/mydb
export LIQUIBASE_COMMAND_USERNAME=$DB_USER
export LIQUIBASE_COMMAND_PASSWORD=$DB_PASSWORD
liquibase update
```

---

## Docker-Based CI (No Liquibase Install Needed)

```yaml
# Use the official Liquibase Docker image in CI
liquibase-migrate:
  image: liquibase/liquibase:4.27
  script:
    - liquibase
        --url=$DB_URL
        --username=$DB_USER
        --password=$DB_PASSWORD
        --changeLogFile=db/changelog/master.xml
        update
```

This avoids installing Liquibase on CI agents and ensures version consistency.

---

## The Tag-Before-Deploy Pattern in CI

```yaml
# In deploy pipeline:
- name: Tag before migration
  run: |
    liquibase tag --tag=${{ github.sha }}

- name: Run migrations
  run: |
    liquibase update

- name: If rollback needed
  if: failure()
  run: |
    liquibase rollback --tag=${{ github.sha }}
```

Using the Git commit SHA as the tag gives you a unique, traceable rollback point tied to source code.

---

## Rollback on Failure Pattern

```yaml
deploy:
  steps:
    - name: Tag current state
      run: liquibase tag --tag=pre-deploy-${{ github.run_id }}

    - name: Apply migrations
      id: migrate
      run: liquibase update

    - name: Deploy application
      id: deploy
      run: ./deploy.sh

    - name: Smoke test
      id: smoke
      run: ./smoke-test.sh

    - name: Rollback on failure
      if: failure() && steps.migrate.outcome == 'success'
      run: liquibase rollback --tag=pre-deploy-${{ github.run_id }}
```

---

## Liquibase in Kubernetes Init Containers

In Kubernetes, run Liquibase as an init container that must succeed before the app container starts:

```yaml
# kubernetes/deployment.yaml
spec:
  initContainers:
    - name: liquibase-migrate
      image: liquibase/liquibase:4.27
      command:
        - liquibase
        - --url=$(DB_URL)
        - --username=$(DB_USER)
        - --password=$(DB_PASSWORD)
        - --changeLogFile=db/changelog/master.xml
        - update
      env:
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
  containers:
    - name: app
      image: myapp:latest
      # App only starts if init container succeeds
```

---

## Key Takeaways

- Automate: `validate` and `futureRollbackSQL` on every PR, `update` on every deploy
- Use environment variables for credentials — never commit them
- Tag with Git SHA before every deploy — perfect rollback traceability
- Use the official Liquibase Docker image in CI — no installation needed
- In Kubernetes, use init containers to guarantee migrations run before app startup
- Gate deploys on migration success — a failed migration should block the deploy

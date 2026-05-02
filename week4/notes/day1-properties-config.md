# Week 4, Day 1 — Properties Files and Environment Config

## No New Changelog Today
Day 1 is about configuration management. No schema changes — just understanding how to configure Liquibase cleanly for multiple environments.

---

## `liquibase.properties` — The Config File

Liquibase reads `liquibase.properties` from the working directory by default. Any CLI flag can be set here to avoid repeating it on every command.

```properties
# liquibase.properties (committed to Git — NO secrets)
changeLogFile=week4/changelogs/master.xml
driver=org.postgresql.Driver
logLevel=INFO
outputDefaultSchema=false
outputDefaultCatalog=false
```

Override the file location:
```bash
liquibase --defaults-file=/path/to/custom.properties update
```

---

## Full Properties Reference

```properties
# ── Connection ─────────────────────────────────────────────
url=jdbc:postgresql://localhost:5432/learndb
username=liquibase
password=liquibase123
driver=org.postgresql.Driver

# ── Changelog ──────────────────────────────────────────────
changeLogFile=db/changelog/master.xml

# ── Filtering ──────────────────────────────────────────────
contexts=dev
labelFilter=feature-x

# ── Schema ─────────────────────────────────────────────────
defaultSchemaName=public
liquibaseSchemaName=public       # schema for DATABASECHANGELOG tables
defaultCatalogName=learndb

# ── Logging ────────────────────────────────────────────────
logLevel=INFO                    # OFF, SEVERE, WARNING, INFO, FINE, FINEST
logFile=liquibase.log

# ── Behaviour ──────────────────────────────────────────────
outputDefaultSchema=false        # don't print schema name in generated SQL
outputDefaultCatalog=false
strict=false                     # strict mode: fail on unknown attributes
```

---

## Environment-Specific Properties Files

**Never put credentials in a committed file.** Use separate files per environment:

```
liquibase.properties           ← committed: changeLogFile, driver, logLevel
liquibase-dev.properties       ← local only (.gitignored): url, username, password
liquibase-prod.properties      ← never committed, stored in secrets manager
```

`.gitignore`:
```
liquibase-dev.properties
liquibase-prod.properties
liquibase.properties.local
```

Usage:
```bash
# Dev
liquibase --defaults-file=liquibase-dev.properties update

# Prod
liquibase --defaults-file=liquibase-prod.properties --contexts=prod update
```

---

## Environment Variables Override Properties

Liquibase reads `LIQUIBASE_COMMAND_*` environment variables and overrides the properties file:

| Environment Variable | Equivalent Property |
|---------------------|---------------------|
| `LIQUIBASE_COMMAND_URL` | `url` |
| `LIQUIBASE_COMMAND_USERNAME` | `username` |
| `LIQUIBASE_COMMAND_PASSWORD` | `password` |
| `LIQUIBASE_COMMAND_CHANGELOG_FILE` | `changeLogFile` |
| `LIQUIBASE_COMMAND_CONTEXTS` | `contexts` |
| `LIQUIBASE_COMMAND_LABEL_FILTER` | `labelFilter` |
| `LIQUIBASE_LOG_LEVEL` | `logLevel` |

```bash
# In CI pipeline — no file needed for secrets:
export LIQUIBASE_COMMAND_URL=jdbc:postgresql://prod-db:5432/learndb
export LIQUIBASE_COMMAND_USERNAME=$DB_USER
export LIQUIBASE_COMMAND_PASSWORD=$DB_PASSWORD
export LIQUIBASE_COMMAND_CONTEXTS=prod

liquibase update   # reads URL/credentials from env, changeLogFile from .properties
```

---

## Priority Order (Highest to Lowest)

```
1. CLI flags           --url=...
2. Environment vars    LIQUIBASE_COMMAND_URL=...
3. Properties file     url=... in liquibase.properties
4. Defaults
```

---

## Multiple Environments with One Properties File

Use a base file with placeholders and override per-environment values:

```properties
# liquibase.properties (base — committed)
changeLogFile=db/changelog/master.xml
driver=org.postgresql.Driver
logLevel=${LOG_LEVEL:INFO}
```

Then set only the environment-specific values via env vars in each deployment environment.

---

## Flow File (Liquibase 4.15+)

A flow file chains multiple Liquibase commands into a reusable pipeline — the Liquibase-native alternative to shell scripts:

```yaml
# liquibase.flowfile.yaml
stages:
  validate:
    actions:
      - type: liquibase
        command: validate

  generate-preview:
    actions:
      - type: liquibase
        command: updateSQL
        cmdArgs:
          output-file: migration-preview.sql

  deploy:
    actions:
      - type: liquibase
        command: tag
        cmdArgs: { tag: "pre-deploy-${DEPLOY_ID}" }
      - type: liquibase
        command: update
```

Run the full flow:
```bash
liquibase flow --flow-file=liquibase.flowfile.yaml
```

This is a Liquibase Pro feature in older versions but available in Community from 4.24.

---

## Key Takeaways

- Commit: `changeLogFile`, `driver`, `logLevel` — nothing sensitive
- Never commit: `url`, `username`, `password`
- Use environment variables in CI/CD — they override the properties file
- Priority: CLI flags → env vars → properties file → defaults
- Separate properties files per environment, `.gitignore` the credential ones
- Flow files replace shell scripts with a structured, portable pipeline definition

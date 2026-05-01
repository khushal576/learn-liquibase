# Learn Liquibase — Hands-On Course

A practical, week-by-week Liquibase course built around a real PostgreSQL database running in Docker.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose
- Basic SQL knowledge
- A SQL client (psql, DBeaver, or TablePlus)

---

## Project Structure

```
learn_liquibse/
├── README.md
├── liquibase.properties
├── docker/
│   └── docker-compose.yml
├── week1/
│   ├── notes/
│   │   ├── day1-why-liquibase.md
│   │   ├── day2-core-concepts.md
│   │   ├── day3-first-changeset-xml.md
│   │   ├── day4-sql-format.md
│   │   ├── day5-yaml-format.md
│   │   ├── day6-cli-commands.md
│   │   └── day7-databasechangelog.md
│   └── changelogs/
│       ├── master.xml
│       ├── day3-create-users-xml.xml
│       ├── day4-create-orders-sql.sql
│       ├── day5-create-products-yaml.yaml
│       ├── day6-add-constraints.xml
│       └── day7-seed-data.xml
└── week2/
    ├── notes/
    │   ├── day1-table-column-ops.md
    │   ├── day2-constraints-indexes.md
    │   ├── day3-data-migrations.md
    │   ├── day4-modify-types.md
    │   ├── day5-raw-sql.md
    │   ├── day6-organizing-changelogs.md
    │   └── day7-contexts-labels.md
    ├── changelogs/
    │   ├── master.xml
    │   ├── day1-table-column-ops.xml
    │   ├── day2-constraints-indexes.xml
    │   ├── day3-data-migrations.xml
    │   ├── day4-modify-types.xml
    │   ├── day5-raw-sql.xml
    │   ├── day7-contexts-labels.xml
    │   └── patches/
    │       ├── patch-001-add-discount.xml
    │       └── patch-002-add-coupon.xml
    └── sql/
        ├── create-audit-log.sql
        ├── products-seed.csv
        └── categories-seed.csv
```

---

## Quick Start

### 1. Start PostgreSQL

```bash
cd docker
docker compose up postgres -d
```

Wait for the health check to pass (~5 seconds).

### 2. Run Week 1 migrations

```bash
docker compose run --rm liquibase-week1
```

### 3. Run Week 2 migrations (includes Week 1)

```bash
docker compose run --rm liquibase-week2
```

### 4. Run with contexts or labels

```bash
# Week 2 with dev seed data
docker compose run --rm liquibase-week2 \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week2/changelogs/master.xml \
  --contexts=dev update

# Week 2 with feature label
docker compose run --rm liquibase-week2 \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week2/changelogs/master.xml \
  --labels="feature-loyalty-points" update
```

### 5. Connect and verify

```bash
docker exec -it liquibase_db psql -U liquibase -d learndb

# Inside psql
\dt                             -- list all tables
\dv                             -- list all views
SELECT id, author, contexts, labels, dateexecuted
FROM databasechangelog ORDER BY orderexecuted;
\q
```

---

## Common Liquibase Commands (via Docker)

```bash
# Shorthand for any custom command (replace week2 as needed)
WEEK2="--url=jdbc:postgresql://postgres:5432/learndb --username=liquibase --password=liquibase123 --changeLogFile=week2/changelogs/master.xml"

# Check pending changesets
docker compose run --rm liquibase $WEEK2 status --verbose

# Validate changelog syntax (no DB changes)
docker compose run --rm liquibase $WEEK2 validate

# Preview SQL without applying
docker compose run --rm liquibase $WEEK2 updateSQL

# Tag the current state
docker compose run --rm liquibase $WEEK2 tag --tag=week2-complete

# Rollback to a tag
docker compose run --rm liquibase $WEEK2 rollback --tag=week2-complete

# Rollback last N changesets
docker compose run --rm liquibase $WEEK2 rollbackCount --count=2

# Preview rollback SQL
docker compose run --rm liquibase $WEEK2 rollbackSQL --tag=week2-complete
```

---

## Week 1 — Day by Day

| Day | Notes | Changelog | What you learn |
|-----|-------|-----------|----------------|
| 1 | [day1-why-liquibase.md](week1/notes/day1-why-liquibase.md) | — | Why Liquibase exists, the schema drift problem |
| 2 | [day2-core-concepts.md](week1/notes/day2-core-concepts.md) | — | Changelog, changeset, DATABASECHANGELOG architecture |
| 3 | [day3-first-changeset-xml.md](week1/notes/day3-first-changeset-xml.md) | [day3-create-users-xml.xml](week1/changelogs/day3-create-users-xml.xml) | First changeset in XML, `createTable` |
| 4 | [day4-sql-format.md](week1/notes/day4-sql-format.md) | [day4-create-orders-sql.sql](week1/changelogs/day4-create-orders-sql.sql) | SQL format, multiple changesets per file |
| 5 | [day5-yaml-format.md](week1/notes/day5-yaml-format.md) | [day5-create-products-yaml.yaml](week1/changelogs/day5-create-products-yaml.yaml) | YAML format, foreign keys |
| 6 | [day6-cli-commands.md](week1/notes/day6-cli-commands.md) | [day6-add-constraints.xml](week1/changelogs/day6-add-constraints.xml) | Full CLI toolkit: status, validate, tag, rollback |
| 7 | [day7-databasechangelog.md](week1/notes/day7-databasechangelog.md) | [day7-seed-data.xml](week1/changelogs/day7-seed-data.xml) | DATABASECHANGELOG internals, contexts |

---

## Week 2 — Day by Day

| Day | Notes | Changelog | What you learn |
|-----|-------|-----------|----------------|
| 1 | [day1-table-column-ops.md](week2/notes/day1-table-column-ops.md) | [day1-table-column-ops.xml](week2/changelogs/day1-table-column-ops.xml) | `addColumn`, `dropColumn`, `renameTable`, safe drop pattern |
| 2 | [day2-constraints-indexes.md](week2/notes/day2-constraints-indexes.md) | [day2-constraints-indexes.xml](week2/changelogs/day2-constraints-indexes.xml) | Composite unique, partial indexes, NOT NULL addition |
| 3 | [day3-data-migrations.md](week2/notes/day3-data-migrations.md) | [day3-data-migrations.xml](week2/changelogs/day3-data-migrations.xml) | `insert`, `update`, `delete`, `loadData`, `loadUpdateData` |
| 4 | [day4-modify-types.md](week2/notes/day4-modify-types.md) | [day4-modify-types.xml](week2/changelogs/day4-modify-types.xml) | `modifyDataType`, `addDefaultValue`, widening vs narrowing |
| 5 | [day5-raw-sql.md](week2/notes/day5-raw-sql.md) | [day5-raw-sql.xml](week2/changelogs/day5-raw-sql.xml) | `<sql>`, `<sqlFile>`, views, functions, triggers, `runOnChange` |
| 6 | [day6-organizing-changelogs.md](week2/notes/day6-organizing-changelogs.md) | [patches/](week2/changelogs/patches/) | `<include>`, `<includeAll>`, directory structure |
| 7 | [day7-contexts-labels.md](week2/notes/day7-contexts-labels.md) | [day7-contexts-labels.xml](week2/changelogs/day7-contexts-labels.xml) | Context expressions, labels, feature flags |

---

## The Golden Rules

1. **Never edit a deployed changeset** — the MD5 hash will break. Add a new one instead.
2. **One logical change per changeset** — makes rollbacks surgical.
3. **Tag before every release** — `liquibase tag --tag=v1.0.0`
4. **Use contexts** — `context="dev"` keeps seed data out of production.
5. **Always write rollback blocks** — discover broken rollbacks in dev, not prod.
6. **Changelogs live in Git** — treat schema changes exactly like code.

---

## Teardown

```bash
# Stop containers and remove volumes (wipes the database)
cd docker
docker compose down -v
```

---

## Course Roadmap

- [x] **Week 1** — Foundations: changelogs, changesets, core CLI
- [x] **Week 2** — Change types: columns, constraints, data migrations, contexts
- [ ] **Week 3** — Rollbacks, `diff`, `generateChangeLog`, CI/CD integration
- [ ] **Week 4** — Advanced: preconditions, multi-schema, Maven/Gradle, production patterns

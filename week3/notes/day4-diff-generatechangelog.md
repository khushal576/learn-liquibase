# Week 3, Day 4 — diff and generateChangeLog

## Hands-On File
Open: `week3/changelogs/day4-diff-target.xml`

---

## What is `liquibase diff`?

`diff` compares two databases (or a database vs a snapshot) and reports what is different between them.

Use cases:
- Detect **schema drift** (production DB has manual changes not in changelogs)
- Compare dev vs staging to find missing migrations
- Verify your changelogs actually produce the schema you intended
- Audit what changed between releases

---

## Setting Up Two Databases for the Exercise

You'll need two databases: the current one and a "target" state.

```bash
cd docker

# Create a second database in the same Postgres container
docker exec -it liquibase_db psql -U liquibase -d postgres \
  -c "CREATE DATABASE learndb_v2 OWNER liquibase;"

# Apply only week1+2 to learndb (current)
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week2/changelogs/master.xml update

# Apply week1+2+3 to learndb_v2 (reference/target)
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb_v2 \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml update
```

---

## `liquibase diff` — Compare Two Databases

```bash
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase \
  --password=liquibase123 \
  --referenceUrl=jdbc:postgresql://postgres:5432/learndb_v2 \
  --referenceUsername=liquibase \
  --referencePassword=liquibase123 \
  diff
```

Output shows exactly what `learndb` is missing compared to `learndb_v2`:
```
Diff Results:
Reference Database: liquibase @ jdbc:postgresql://postgres:5432/learndb_v2
Comparison Database: liquibase @ jdbc:postgresql://postgres:5432/learndb

Changelog Differences:
  Missing Tables:
    product_reviews
    wishlist_items
    notifications
    ...
  Missing Columns:
    orders.shipping_address
    orders.shipped_at
    ...
```

---

## `liquibase diffChangeLog` — Turn a Diff Into a Changelog

This is the killer feature. It auto-generates a changelog from the difference between two databases:

```bash
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase \
  --password=liquibase123 \
  --referenceUrl=jdbc:postgresql://postgres:5432/learndb_v2 \
  --referenceUsername=liquibase \
  --referencePassword=liquibase123 \
  --changeLogFile=week3/changelogs/generated-diff.xml \
  diffChangeLog
```

This generates `generated-diff.xml` with changesets that, when applied to `learndb`, will make it match `learndb_v2`.

**Important:** Review the generated changelog before using it — auto-generated changelogs:
- May include unwanted changes (sequences, permissions)
- Won't have rollback blocks — add them manually
- May use generic changeset IDs — rename them to your convention

---

## `liquibase generateChangeLog` — Reverse-Engineer an Existing Schema

Use this to bring an existing database (no changelog history) under Liquibase control:

```bash
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase \
  --password=liquibase123 \
  --changeLogFile=week3/changelogs/generated-schema.xml \
  generateChangeLog
```

This creates a changelog representing the **current full schema** of `learndb`. Then:

```bash
# Mark all those changesets as already applied (don't re-run them)
liquibase changeLogSync --changeLogFile=week3/changelogs/generated-schema.xml
```

`changeLogSync` inserts all changeset IDs into `DATABASECHANGELOG` without running any SQL. This is how you onboard an existing database to Liquibase without recreating it.

---

## The Onboarding Workflow (Existing DB → Liquibase)

```
Step 1: generateChangeLog   → capture current schema as a changelog
Step 2: Review and clean up the generated file (rename IDs, add author, add rollbacks)
Step 3: changeLogSync       → mark those changesets as "already applied"
Step 4: All future changes  → write new changesets and run update normally
```

---

## Detecting Schema Drift in Production

Schema drift happens when someone runs SQL directly in production without using Liquibase.

```bash
# Take a snapshot of what your changelogs SHOULD produce
liquibase snapshot --snapshotFormat=json > expected-snapshot.json

# Diff the live DB against the snapshot
liquibase diff --referenceUrl=offline:postgresql?snapshot=expected-snapshot.json
```

If the diff shows unexpected differences, someone modified the database manually. Investigate and add a changeset to capture the change.

---

## Key Takeaways

- `diff` compares two live databases and reports differences
- `diffChangeLog` auto-generates a changelog from those differences
- `generateChangeLog` reverse-engineers an entire existing schema into a changelog
- `changeLogSync` marks changesets as applied without running them — for onboarding existing DBs
- Always review auto-generated changelogs — they need cleanup before committing to Git
- Run `diff` regularly between environments to detect schema drift

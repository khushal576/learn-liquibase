# Week 3, Day 1 — Rollback Strategies

## Hands-On File
Open: `week3/changelogs/day1-rollback-practice.xml`

---

## The Three Rollback Commands

| Command | When to Use |
|---------|-------------|
| `rollback --tag=<tag>` | Roll back to a named point in time — most common in prod |
| `rollbackCount --count=N` | Undo the last N changesets — useful in dev |
| `rollbackToDate --date="2024-01-15T10:00:00"` | Roll back to a specific timestamp |

---

## Tag-Based Rollback (Recommended for Production)

The golden workflow — always tag before deploying:

```bash
# Step 1: Tag BEFORE applying new changes
liquibase tag --tag=v2.3.0-pre

# Step 2: Apply changes
liquibase update

# Step 3: If something goes wrong
liquibase rollback --tag=v2.3.0-pre
```

The tag is stored in the `TAG` column of the last row in `DATABASECHANGELOG` at the moment you run `tag`. Rolling back to it undoes every changeset applied after that row.

---

## Hands-On Exercise (run in order)

```bash
# 1. Start clean
cd docker && docker compose up postgres -d
docker compose run --rm liquibase-week2      # apply week1+2

# 2. Tag before week3 changes
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  tag --tag=before-week3

# 3. Apply week3 day1 changes
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  update

# 4. Verify what was applied
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"

# 5. Tag after reviews table (point B)
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  tag --tag=after-reviews

# 6. PREVIEW rollback to before-week3 (does NOT apply)
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  rollbackSQL --tag=before-week3

# 7. Actually rollback
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  rollback --tag=before-week3

# 8. Confirm tables are gone
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"

# 9. Re-apply
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  update
```

---

## Count-Based Rollback

```bash
# Undo the last 3 changesets
liquibase rollbackCount --count=3

# Preview what would be undone
liquibase rollbackCountSQL --count=3
```

Use this in development when you're iterating and just want to undo your last few changes. Avoid in production — count-based rollbacks are fragile if other deployments have run between now and when you added your changes.

---

## Date-Based Rollback

```bash
# Rollback to a specific point in time
liquibase rollbackToDate --date="2024-06-15T14:30:00"

# Preview
liquibase rollbackToDateSQL --date="2024-06-15T14:30:00"
```

Liquibase uses the `DATEEXECUTED` column in `DATABASECHANGELOG` to determine which changesets were applied after the given date and undoes those.

Date format: `yyyy-MM-dd'T'HH:mm:ss` or `yyyy-MM-dd HH:mm:ss`

---

## The `futureRollbackSQL` Command

```bash
liquibase futureRollbackSQL --changeLogFile=week3/changelogs/master.xml
```

This shows you what SQL would be needed to roll back changes that are **pending but not yet applied**. Useful to:
- Verify rollback scripts are correct before deploying
- Give DBAs a preview of the rollback plan
- Include in deployment documentation

---

## What Gets Rolled Back?

When you rollback to a tag:
1. Liquibase finds all changesets in `DATABASECHANGELOG` applied AFTER the tag row
2. For each, it runs the `<rollback>` block (or auto-generated rollback)
3. It removes those rows from `DATABASECHANGELOG`
4. The database is back to the tagged state

**Changesets with no rollback block:**
- Some built-in changes auto-generate rollback (createTable → dropTable)
- Some cannot be auto-rolled back (dropTable, dropColumn, insert data)
- If Liquibase can't determine the rollback, it throws an error
- Fix: always write explicit rollback blocks

---

## Key Takeaways

- Always `tag` before deploying — it's the safety net
- `rollbackSQL` before `rollback` — preview first, always
- Tag-based is safest; count-based is for dev only; date-based is a last resort
- `futureRollbackSQL` lets you verify rollback plans before deployment
- Changes that delete data cannot truly be rolled back — only the schema can be restored

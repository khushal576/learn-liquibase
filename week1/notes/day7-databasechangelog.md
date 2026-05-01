# Day 7 — DATABASECHANGELOG Deep Dive & Contexts

## Hands-On File
Open: `week1/changelogs/day7-seed-data.xml`

---

## The DATABASECHANGELOG Table — Full Column Reference

Connect to the DB and inspect it:
```bash
docker exec -it liquibase_db psql -U liquibase -d learndb
```

```sql
-- See the full table structure
\d databasechangelog

-- See all applied changesets
SELECT id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, tag
FROM databasechangelog
ORDER BY orderexecuted;
```

| Column | Type | What It Means |
|--------|------|---------------|
| `ID` | VARCHAR | Changeset `id` attribute |
| `AUTHOR` | VARCHAR | Changeset `author` attribute |
| `FILENAME` | VARCHAR | Path to the changelog file |
| `DATEEXECUTED` | TIMESTAMP | When Liquibase ran this changeset |
| `ORDEREXECUTED` | INT | Sequence number (1, 2, 3...) |
| `EXECTYPE` | VARCHAR | See below |
| `MD5SUM` | VARCHAR | Hash of changeset content (tamper detection) |
| `DESCRIPTION` | VARCHAR | Auto-generated summary of the change |
| `COMMENTS` | VARCHAR | Your `<comment>` text if you added one |
| `TAG` | VARCHAR | Set by `liquibase tag` command |
| `LIQUIBASE` | VARCHAR | Version of Liquibase that ran this |
| `CONTEXTS` | VARCHAR | Context(s) the changeset ran with |
| `LABELS` | VARCHAR | Labels the changeset has |
| `DEPLOYMENT_ID` | VARCHAR | Groups all changesets from one `update` run |

---

## EXECTYPE Values

| Value | Meaning |
|-------|---------|
| `EXECUTED` | Ran successfully |
| `MARK_RAN` | Manually marked as run (used with `--markNextChangeSetRan`) |
| `RERAN` | Ran again (only for `runAlways=true` changesets) |
| `FAILED` | Failed — Liquibase will retry next run |

---

## The MD5SUM — Tamper Detection

Every changeset's content is hashed. If you edit a deployed changeset, the hash changes and Liquibase throws:

```
Validation Failed:
  1 changesets check sum
    day3-create-users-xml.xml::day3-001::khushal was: 8:abc123...
    but is now: 8:def456...
```

**Fix options (in order of preference):**

1. **Revert your edit** (best option — don't modify deployed changesets)
2. `liquibase clearCheckSums` — clears all stored hashes, Liquibase recalculates on next run
3. Add `validCheckSum` attribute to accept multiple valid hashes (advanced)

---

## Contexts — Environment-Specific Changesets

Contexts let you tag a changeset so it only runs in specific environments.

```xml
<!-- Only runs when --contexts=dev is passed -->
<changeSet id="001" author="khushal" context="dev">
    <insert tableName="users"> ... </insert>
</changeSet>

<!-- Only runs when --contexts=prod is passed -->
<changeSet id="002" author="khushal" context="prod">
    <sql>CREATE INDEX CONCURRENTLY idx_users_email ON users(email);</sql>
</changeSet>

<!-- Runs in BOTH dev and prod -->
<changeSet id="003" author="khushal" context="dev,prod">
    <createTable tableName="audit_log"> ... </createTable>
</changeSet>

<!-- No context = runs in ALL environments (context or not) -->
<changeSet id="004" author="khushal">
    <addColumn tableName="users"> ... </addColumn>
</changeSet>
```

Run with context:
```bash
# Dev environment (includes seed data)
liquibase update --contexts=dev

# Production (no seed data)
liquibase update --contexts=prod
```

**Key rule:** A changeset with no `context` attribute runs in ALL environments, even when you pass `--contexts=prod`. So `context="dev"` is an INCLUDE filter, not an exclude.

---

## Contexts vs Labels

These two features look similar but filter differently:

| Feature | Filter Logic |
|---------|-------------|
| `context` | Changeset runs if its context matches the active context (OR logic) |
| `labels` | More complex expression matching: `AND`, `OR`, `NOT` |

For week 1, stick with `context`. Labels are for advanced multi-team scenarios.

---

## Running Day 7 Seed Data

```bash
# Without context — seed data changesets are SKIPPED
docker compose run --rm liquibase update

# With dev context — seed data RUNS
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --contexts=dev \
  update

# Verify the data was inserted:
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT * FROM users;"
```

---

## The DATABASECHANGELOGLOCK Table

```sql
SELECT * FROM databasechangeloglock;
```

Output when idle:
```
 id | locked | lockgranted | lockedby
----+--------+-------------+----------
  1 | f      |             |
```

When Liquibase is running:
```
 id | locked | lockgranted         | lockedby
----+--------+---------------------+--------------------
  1 | t      | 2024-01-15 10:23:45 | hostname (PID 1234)
```

If a run crashes and `locked = t` is stuck:
```bash
docker compose run --rm liquibase releaseLocks
```

---

## Week 1 Final Exercise — Full Lifecycle

```bash
# 1. Clean slate — tear down and restart
cd docker && docker compose down -v && docker compose up postgres -d

# 2. Apply all week1 changes (no seed data)
docker compose run --rm liquibase update

# 3. Apply with dev seed data
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --contexts=dev update

# 4. Inspect what was applied
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT id, author, exectype, contexts FROM databasechangelog ORDER BY orderexecuted;"

# 5. Tag this state
docker compose run --rm liquibase tag --tag=week1-complete

# 6. Roll back the last 2 changesets
docker compose run --rm liquibase rollbackCount --count=2

# 7. Re-apply to get back to complete
docker compose run --rm liquibase --contexts=dev update

# 8. Roll back all the way to before week1
docker compose run --rm liquibase rollback --tag=week1-complete
```

---

## Week 1 Summary — What You've Learned

| Day | Concept | Command |
|-----|---------|---------|
| 1 | Why Liquibase exists | — |
| 2 | Changelog, changeset, tracking tables | — |
| 3 | XML format, createTable, rollback | `liquibase update` |
| 4 | SQL format, multiple changesets per file | `liquibase update` |
| 5 | YAML format, foreign keys | `liquibase update` |
| 6 | Full CLI toolkit | `status`, `validate`, `updateSQL`, `tag`, `rollback` |
| 7 | DATABASECHANGELOG internals, contexts | `--contexts=dev` |

You're ready for Week 2 — change types, data migrations, and organizing large changelogs.

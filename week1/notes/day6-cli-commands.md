# Day 6 — Essential CLI Commands

## Hands-On File
Open: `week1/changelogs/day6-add-constraints.xml`

---

## The Commands You'll Use Every Day

All commands below use the Docker runner. If you had Liquibase installed locally you'd drop the `docker compose run --rm liquibase` prefix and just type `liquibase <command>`.

---

### `liquibase update`
Apply all pending changesets.

```bash
docker compose run --rm liquibase update
```

This is the main command. Run it every time you pull new changelog files from Git.

---

### `liquibase status`
Show which changesets are pending (not yet applied).

```bash
docker compose run --rm liquibase status --verbose
```

Output looks like:
```
3 changesets have not been applied to liquibase@jdbc:postgresql://...
     day6-add-constraints.xml::day6-001::khushal
     day6-add-constraints.xml::day6-002::khushal
     day6-add-constraints.xml::day6-003::khushal
```

Use this to check before deploying: "what will `update` actually do?"

---

### `liquibase validate`
Check that all changelog files are syntactically correct — without touching the DB.

```bash
docker compose run --rm liquibase validate
```

Run this in CI before `update`. It catches:
- XML/YAML syntax errors
- Missing referenced files
- Duplicate changeset IDs
- Invalid change type attributes

---

### `liquibase updateSQL`
Preview the exact SQL Liquibase WOULD run — without applying anything.

```bash
docker compose run --rm liquibase updateSQL
```

Output is the raw SQL statements. Useful for:
- Code review of migrations before merging
- DBAs who want to review before approving
- Debugging why a migration fails

---

### `liquibase tag`
Bookmark the current state of the database with a name.

```bash
docker compose run --rm liquibase tag --tag=week1-day6
```

This writes the tag name into the `TAG` column of the last row in `DATABASECHANGELOG`. Think of it like `git tag`. Always tag before a release.

---

### `liquibase rollback`
Undo all changesets applied after a given tag.

```bash
docker compose run --rm liquibase rollback --tag=week1-day6
```

This runs the `<rollback>` blocks of each changeset in reverse order, back to the tagged state.

---

### `liquibase rollbackCount`
Undo the last N changesets.

```bash
docker compose run --rm liquibase rollbackCount --count=2
```

Useful when you don't have a tag — just "undo the last 2 things".

---

### `liquibase rollbackSQL`
Preview what the rollback WOULD do — without actually doing it.

```bash
docker compose run --rm liquibase rollbackSQL --tag=week1-day6
```

Always run this before an actual rollback in production.

---

### `liquibase history`
List all changesets that have been applied, with timestamps.

```bash
docker compose run --rm liquibase history
```

---

### `liquibase releaseLocks`
Force-release the DATABASECHANGELOGLOCK if a crashed run left it locked.

```bash
docker compose run --rm liquibase releaseLocks
```

Only use this if you get: `"Waiting for changelog lock..."` and you're sure no other process is running.

---

## Full Practice Session for Day 6

Run these in order and observe the output of each:

```bash
# 1. See what's pending before applying
docker compose run --rm liquibase status --verbose

# 2. Preview the SQL without running
docker compose run --rm liquibase updateSQL

# 3. Validate changelog syntax
docker compose run --rm liquibase validate

# 4. Tag the DB before applying day6 changes
docker compose run --rm liquibase tag --tag=before-day6

# 5. Apply the changes
docker compose run --rm liquibase update

# 6. Confirm nothing is pending anymore
docker compose run --rm liquibase status

# 7. See history
docker compose run --rm liquibase history

# 8. Preview rollback SQL (safe)
docker compose run --rm liquibase rollbackSQL --tag=before-day6

# 9. Actually rollback
docker compose run --rm liquibase rollback --tag=before-day6

# 10. Re-apply
docker compose run --rm liquibase update
```

---

## Key Takeaways

- `status` → what will run
- `validate` → syntax check
- `updateSQL` → SQL preview (dry run)
- `update` → actually apply
- `tag` → bookmark before a release
- `rollback --tag` → undo to a bookmark
- `rollbackSQL` → preview rollback before doing it
- `releaseLocks` → emergency only

**Workflow habit:** `validate → updateSQL → tag → update`

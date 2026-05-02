# Week 4, Day 5 — Large Data Migrations

## Hands-On File
Open: `week4/changelogs/day5-large-migrations.xml`

---

## Why Large Migrations Are Different

On a small table (< 100k rows), `ALTER TABLE`, `CREATE INDEX`, `UPDATE` all complete in milliseconds. On a large table (10M+ rows), the same operations can:

- Lock the table for minutes → downtime
- Fill up transaction logs → disk exhaustion
- Time out in cloud databases with max statement timeouts
- Cause replication lag on replicas

The patterns in this section apply to tables with millions of rows. For small tables, standard changesets work fine.

---

## Pattern 1: Batched Backfill (Adding a Column to a Large Table)

**Never do:**
```sql
-- On a 10M row table, this is one giant transaction
ALTER TABLE orders ADD COLUMN priority SMALLINT DEFAULT 0 NOT NULL;
```

**Instead — 3 changesets:**

```
Changeset 1: Add column as nullable (instant)
Changeset 2: Backfill in batches (runs slowly but without a lock)
Changeset 3: Add NOT NULL constraint with NOT VALID + VALIDATE
```

From `day5-large-migrations.xml`:

**Step 1** — instant, no lock:
```xml
<changeSet id="w4-day5-001">
    <addColumn tableName="orders">
        <column name="priority" type="SMALLINT" defaultValueNumeric="0"/>
    </addColumn>
</changeSet>
```

**Step 2** — batched update via a PL/pgSQL loop:
```xml
<changeSet id="w4-day5-002">
    <sql splitStatements="false">
        DO $$
        DECLARE
            batch_size INT := 1000;
            rows_updated INT;
        BEGIN
            LOOP
                UPDATE orders
                SET priority = CASE WHEN total > 500 THEN 2 WHEN total > 100 THEN 1 ELSE 0 END
                WHERE id IN (
                    SELECT id FROM orders WHERE priority IS NULL ORDER BY id LIMIT batch_size
                );
                GET DIAGNOSTICS rows_updated = ROW_COUNT;
                EXIT WHEN rows_updated = 0;
                PERFORM pg_sleep(0.01);   -- reduce I/O pressure
            END LOOP;
        END $$;
    </sql>
</changeSet>
```

**Step 3** — NOT NULL without full table lock:
```xml
<changeSet id="w4-day5-003">
    <sql>
        ALTER TABLE orders ADD CONSTRAINT nn_orders_priority CHECK (priority IS NOT NULL) NOT VALID;
        ALTER TABLE orders VALIDATE CONSTRAINT nn_orders_priority;
    </sql>
</changeSet>
```

`NOT VALID` skips validation of existing rows (fast). `VALIDATE CONSTRAINT` validates them separately with a weaker lock level.

---

## Pattern 2: `CREATE INDEX CONCURRENTLY`

Standard `CREATE INDEX` takes `AccessExclusiveLock` — blocks all reads and writes until complete.

`CREATE INDEX CONCURRENTLY` takes `ShareUpdateExclusiveLock` — allows reads and writes while building the index. Takes 2-3x longer but causes zero downtime.

```xml
<changeSet id="w4-day5-004" runInTransaction="false">
    <!--
        runInTransaction="false" is REQUIRED.
        CONCURRENTLY cannot run inside a transaction block.
    -->
    <sql splitStatements="false">
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_priority_status
            ON orders(priority, status)
            WHERE priority > 0;
    </sql>
    <rollback>
        <sql>DROP INDEX CONCURRENTLY IF EXISTS idx_orders_priority_status;</sql>
    </rollback>
</changeSet>
```

Rules for `runInTransaction="false"`:
- Only use for operations that cannot run in a transaction (CONCURRENTLY, VACUUM, etc.)
- If the changeset fails halfway, it's not rolled back — must handle manually
- Don't mix transactional and non-transactional operations in the same changeset

---

## Pattern 3: Zero-Downtime Column Rename (4-Step Deploy)

Renaming a column while the app is running breaks existing queries. The safe approach uses 4 deployment steps over multiple releases:

```
Deploy 1 (this release):
  - Add new column (url_slug)
  - Copy existing data
  - Add sync trigger to keep both in sync

Deploy 2 (next release):
  - Update application code to use new column name
  - Both columns still exist and in sync

Deploy 3 (after deploy 2 is fully live):
  - Drop sync trigger
  - Drop old column (url_key)
```

From `day5-large-migrations.xml`:

**Deploy 1 changesets:**
```xml
<!-- Add new column and copy data -->
<changeSet id="w4-day5-005">
    <addColumn tableName="categories">
        <column name="url_slug" type="VARCHAR(80)"/>
    </addColumn>
    <sql>UPDATE categories SET url_slug = url_key;</sql>
</changeSet>

<!-- Sync trigger: keep both columns in sync during transition -->
<changeSet id="w4-day5-006" splitStatements="false">
    <sql>
        CREATE OR REPLACE FUNCTION sync_url_columns() RETURNS TRIGGER AS $$
        BEGIN
            IF NEW.url_key IS DISTINCT FROM OLD.url_key THEN NEW.url_slug = NEW.url_key; END IF;
            IF NEW.url_slug IS DISTINCT FROM OLD.url_slug THEN NEW.url_key = NEW.url_slug; END IF;
            RETURN NEW;
        END; $$ LANGUAGE plpgsql;

        CREATE TRIGGER trg_sync_url_columns
            BEFORE INSERT OR UPDATE ON categories
            FOR EACH ROW EXECUTE FUNCTION sync_url_columns();
    </sql>
</changeSet>
```

**Deploy 3** (in day7-final-project.xml — `labels="post-rename-cleanup"`):
```xml
<changeSet id="w4-day7-006" labels="post-rename-cleanup">
    <sql splitStatements="false">
        DROP TRIGGER IF EXISTS trg_sync_url_columns ON categories;
        DROP FUNCTION IF EXISTS sync_url_columns();
    </sql>
</changeSet>
```

---

## Choosing the Right Batch Size

| Row Size | Table Rows | Recommended Batch |
|----------|------------|-------------------|
| Small (< 500 bytes) | 10M | 5,000–10,000 |
| Medium (500B–2KB) | 10M | 1,000–5,000 |
| Large (> 2KB) | 10M | 100–500 |
| Any | Replica lag sensitive | 500–1,000 + pg_sleep(0.05) |

Monitor replication lag while running batched migrations: `SELECT ... FROM pg_stat_replication;`

---

## Large Data Migration Checklist

Before running any large migration on production:

1. **Test with production-scale data** — run against a prod clone first, time it
2. **Check replication lag** — monitor replicas during the migration
3. **Check disk space** — index creation needs ~1.5x the index size temporarily
4. **Schedule off-peak** — even "non-locking" migrations increase I/O
5. **Have the rollback ready and tested** — run `rollbackSQL` and verify it
6. **Monitor `pg_stat_activity`** — watch for long-running queries
7. **Communicate downtime expectations** — even "zero downtime" migrations add latency

---

## Key Takeaways

- Batch large backfills: each batch commits independently, no single giant transaction
- `CREATE INDEX CONCURRENTLY` for zero-locking index creation (requires `runInTransaction="false"`)
- `NOT VALID` + `VALIDATE CONSTRAINT` for safe NOT NULL addition at scale
- Zero-downtime column rename takes 3 deployment cycles — sync trigger bridges the gap
- Always test large migrations against a production-sized clone before running in prod
- Monitor replication lag — batch migrations can cause replicas to fall behind

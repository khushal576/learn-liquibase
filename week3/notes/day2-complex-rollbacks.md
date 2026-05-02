# Week 3, Day 2 — Writing Complex Rollback Blocks

## Hands-On File
Open: `week3/changelogs/day2-complex-rollbacks.xml`

---

## Auto-Generated vs Explicit Rollbacks

Liquibase can auto-generate rollback SQL for some change types. For others, you must write it yourself.

| Change Type | Auto Rollback? | Auto Rollback Generated |
|-------------|---------------|------------------------|
| `createTable` | Yes | `DROP TABLE` |
| `addColumn` | Yes | `DROP COLUMN` |
| `createIndex` | Yes | `DROP INDEX` |
| `addForeignKeyConstraint` | Yes | `DROP CONSTRAINT` |
| `addUniqueConstraint` | Yes | `DROP CONSTRAINT` |
| `renameColumn` | Yes | Swaps old/new names |
| `renameTable` | Yes | Swaps old/new names |
| `insert` | **No** | — |
| `update` | **No** | — |
| `delete` | **No** | — |
| `dropTable` | **No** | — |
| `dropColumn` | **No** | — |
| `sql` / `sqlFile` | **No** | — |
| `modifyDataType` | **No** | — |

Rule: if there's any doubt, write an explicit rollback. It also documents intent.

---

## Rollback Block Syntax

### Empty rollback (acknowledge this can't be undone)
```xml
<changeSet id="001" author="khushal">
    <delete tableName="old_logs">
        <where>created_at &lt; '2020-01-01'</where>
    </delete>
    <rollback/>  <!-- empty: data is gone, we accept that -->
</changeSet>
```

### Rollback using a change type
```xml
<rollback>
    <dropTable tableName="product_reviews"/>
</rollback>
```

### Rollback using raw SQL
```xml
<rollback>
    <sql>DROP VIEW IF EXISTS v_review_summary;</sql>
</rollback>
```

### Multi-step rollback (reverse order of changes)
```xml
<changeSet id="001" author="khushal">
    <addColumn tableName="products">
        <column name="supplier_id" type="BIGINT"/>
    </addColumn>
    <createIndex tableName="products" indexName="idx_products_supplier">
        <column name="supplier_id"/>
    </createIndex>
    <rollback>
        <!-- REVERSE ORDER: index first, then column -->
        <dropIndex tableName="products" indexName="idx_products_supplier"/>
        <dropColumn tableName="products" columnName="supplier_id"/>
    </rollback>
</changeSet>
```

---

## The Data-Loss Rollback Problem

When a changeset drops a column or table, data is lost. The rollback can recreate the structure but not the data.

**Best practice before dropping anything with data:**

```xml
<changeSet id="archive-before-drop" author="khushal">
    <!-- 1. Archive the data first -->
    <createTable tableName="users_dob_archive">
        <column name="user_id" type="BIGINT"/>
        <column name="date_of_birth" type="DATE"/>
        <column name="archived_at" type="TIMESTAMP" defaultValueComputed="CURRENT_TIMESTAMP"/>
    </createTable>
    <sql>
        INSERT INTO users_dob_archive(user_id, date_of_birth)
        SELECT id, date_of_birth FROM users WHERE date_of_birth IS NOT NULL;
    </sql>
</changeSet>

<changeSet id="drop-dob-column" author="khushal">
    <!-- 2. Now safe to drop — data is in archive -->
    <dropColumn tableName="users" columnName="date_of_birth"/>
    <rollback>
        <!-- Restore column and re-populate from archive -->
        <addColumn tableName="users">
            <column name="date_of_birth" type="DATE"/>
        </addColumn>
        <sql>
            UPDATE users u
            SET date_of_birth = a.date_of_birth
            FROM users_dob_archive a
            WHERE a.user_id = u.id;
        </sql>
    </rollback>
</changeSet>
```

---

## `runOnChange` Rollback Pattern

For views and functions that use `runOnChange="true"`, the rollback should drop the object so the next `update` can recreate it cleanly:

```xml
<changeSet id="001" author="khushal" runOnChange="true" splitStatements="false">
    <sql>
        CREATE OR REPLACE VIEW v_review_summary AS
        SELECT p.id, COUNT(r.id) AS review_count ...
        FROM products p LEFT JOIN product_reviews r ON r.product_id = p.id
        GROUP BY p.id;
    </sql>
    <rollback>
        <sql>DROP VIEW IF EXISTS v_review_summary;</sql>
    </rollback>
</changeSet>
```

---

## Verifying Rollback Will Work Before Deploying

```bash
# Check rollback SQL for all pending changes (before applying them)
liquibase futureRollbackSQL --changeLogFile=week3/changelogs/master.xml

# Check rollback SQL for what's already applied (after applying)
liquibase rollbackSQL --tag=before-week3

# Apply changes
liquibase update

# Simulate rollback (generates SQL but does NOT execute)
liquibase rollbackSQL --tag=before-week3 > rollback-plan.sql
cat rollback-plan.sql  # review it
```

In a CI pipeline, run `futureRollbackSQL` as part of the PR validation step. If it fails, the PR shouldn't merge.

---

## Running It

```bash
# Apply day2 changes
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml update

# Check the columns table to see supplier_id was added
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d products"

# Check orders_archive was created
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"

# Rollback the last 5 changesets (day2 only)
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  rollbackCount --count=5
```

---

## Key Takeaways

- Multi-step rollbacks must reverse in the opposite order of the original changes
- An empty `<rollback/>` is valid — it signals "this is intentionally irreversible"
- Archive data before dropping it so rollback can restore it
- Always run `futureRollbackSQL` in CI to catch broken rollbacks before prod
- `runOnChange` rollback = drop the object (update will recreate it)

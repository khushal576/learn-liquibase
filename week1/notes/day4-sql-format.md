# Day 4 — SQL Format Changelogs

## Hands-On File
Open: `week1/changelogs/day4-create-orders-sql.sql`

---

## Why SQL Format?

SQL format is ideal when:
- Your team is already comfortable with raw SQL
- You're migrating from manually-managed SQL scripts
- DBAs write the SQL and developers wrap it in Liquibase

The trade-off: you lose some of Liquibase's cross-database portability (XML/YAML change types work on any DB; raw SQL may not).

---

## SQL Format Syntax

Everything is driven by **special SQL comments**:

```sql
--liquibase formatted sql          ← REQUIRED: must be line 1

--changeset author:id              ← starts a new changeset
CREATE TABLE orders (...);         ← your SQL
--rollback DROP TABLE orders;      ← rollback SQL (on same line or next lines)

--changeset author:id2             ← starts another changeset
CREATE INDEX ...;
--rollback DROP INDEX ...;
```

### Changeset options (on the --changeset line)

```sql
--changeset khushal:001 runOnChange:true context:dev labels:feature-x splitStatements:true
```

| Option | Default | Meaning |
|--------|---------|---------|
| `runOnChange` | false | Re-run if content changes |
| `runAlways` | false | Run every deploy |
| `context` | (all) | Only run in this context |
| `splitStatements` | true | Split on `;` (set false for stored procs) |
| `endDelimiter` | `;` | Change statement delimiter |
| `stripComments` | true | Remove comments before running |

---

## Breaking Down day4-create-orders-sql.sql

```sql
--changeset khushal:day4-001
CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT        NOT NULL,
    status      VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    total       NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id)
);
--rollback DROP TABLE orders;
```

Notice:
- Three separate changesets in one file: the table, then the index, then the check constraint
- Each has its own `--rollback` — so you can roll back individual changesets
- The FK is defined inline in the CREATE TABLE (this is SQL, so you can write it however you want)

---

## Multi-Statement Changesets

By default, `splitStatements:true` — Liquibase splits on `;`.

For a **stored procedure or function** that contains `;` internally, you must use a different delimiter:

```sql
--changeset khushal:005 splitStatements:false
CREATE OR REPLACE FUNCTION get_user_count()
RETURNS INT AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM users);
END;
$$ LANGUAGE plpgsql;
--rollback DROP FUNCTION get_user_count();
```

Or use `endDelimiter`:
```sql
--changeset khushal:005 endDelimiter:$$
CREATE OR REPLACE FUNCTION ... $$ LANGUAGE plpgsql;
$$
```

---

## Running It

```bash
# Make sure postgres is running, then:
docker compose run --rm liquibase

# Connect and verify the orders table + index + constraint:
docker exec -it liquibase_db psql -U liquibase -d learndb

# Inside psql:
\d orders                          -- show table structure with constraints
\di                                -- list all indexes
SELECT * FROM databasechangelog;   -- should now show day4-001, day4-002, day4-003
```

---

## Comparing SQL vs XML for the Same Change

SQL format:
```sql
--changeset khushal:001
CREATE INDEX idx_orders_user ON orders(user_id);
--rollback DROP INDEX idx_orders_user;
```

XML format:
```xml
<changeSet id="001" author="khushal">
    <createIndex tableName="orders" indexName="idx_orders_user">
        <column name="user_id"/>
    </createIndex>
    <rollback>
        <dropIndex tableName="orders" indexName="idx_orders_user"/>
    </rollback>
</changeSet>
```

Both do the exact same thing. XML is portable across DB engines; SQL format gives you full SQL power.

---

## Key Takeaways

- SQL format is just regular SQL with special `--liquibase` and `--changeset` comments
- One file can have many changesets — each is tracked independently
- Always use `splitStatements:false` for stored procedures and functions
- SQL format is the easiest migration path from "manual SQL scripts" to Liquibase

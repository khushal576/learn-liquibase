# Week 2, Day 5 — Raw SQL and sqlFile Change Types

## Hands-On File
Open: `week2/changelogs/day5-raw-sql.xml`
Open: `week2/sql/create-audit-log.sql`

---

## When to Use `<sql>` vs Built-in Change Types

| Use built-in change type when... | Use `<sql>` when... |
|----------------------------------|---------------------|
| `createTable`, `addColumn`, etc. exist | Creating a VIEW |
| The change is portable across DB engines | Creating a stored function/procedure |
| You want Liquibase to generate rollback | Creating a trigger |
| Team preference for structured format | DBA writes raw SQL |
| | PostgreSQL-specific features (partial index, CONCURRENTLY) |

Built-in types are cross-database portable. `<sql>` locks you to your target DB — but gives you the full power of that DB.

---

## The `<sql>` Change Type

```xml
<changeSet id="001" author="khushal">
    <sql>
        CREATE OR REPLACE VIEW v_order_summary AS
        SELECT o.id, u.username, o.status, o.total
        FROM orders o JOIN users u ON u.id = o.user_id;
    </sql>
    <rollback>
        <sql>DROP VIEW IF EXISTS v_order_summary;</sql>
    </rollback>
</changeSet>
```

Key attributes:

| Attribute | Default | Purpose |
|-----------|---------|---------|
| `splitStatements` | `true` | Split SQL on `;` — set `false` for functions/procedures |
| `endDelimiter` | `;` | Statement delimiter — change for stored procs |
| `stripComments` | `true` | Remove comments before running |

---

## `splitStatements="false"` — Critical for Functions and Triggers

Without `splitStatements="false"`, Liquibase splits your function body at every semicolon and sends broken fragments to the DB:

```xml
<!-- WRONG: Liquibase splits at every ; inside the function body -->
<changeSet id="001" author="khushal">
    <sql>
        CREATE OR REPLACE FUNCTION get_count() RETURNS INT AS $$
        BEGIN
            RETURN (SELECT COUNT(*) FROM users);  -- ← Liquibase stops here!
        END;
        $$ LANGUAGE plpgsql;
    </sql>
</changeSet>

<!-- CORRECT -->
<changeSet id="001" author="khushal" splitStatements="false">
    <sql>
        CREATE OR REPLACE FUNCTION get_count() RETURNS INT AS $$
        BEGIN
            RETURN (SELECT COUNT(*) FROM users);
        END;
        $$ LANGUAGE plpgsql;
    </sql>
</changeSet>
```

---

## Multiple Statements in One `<sql>` Block

When `splitStatements="false"`, the entire content is sent as one statement.
If you need multiple independent statements (like creating a function AND a trigger), you must either:

1. Use separate `<sql>` tags in the same changeset:
```xml
<changeSet id="001" author="khushal" splitStatements="false">
    <sql>CREATE OR REPLACE FUNCTION set_updated_at() ...</sql>
    <sql>CREATE TRIGGER trg_users_updated_at ...</sql>
</changeSet>
```

2. Or use `endDelimiter` to split on a custom delimiter:
```xml
<changeSet id="001" author="khushal" endDelimiter="$$">
    CREATE OR REPLACE FUNCTION ... $$ LANGUAGE plpgsql;
    $$
</changeSet>
```

---

## The `<sqlFile>` Change Type

```xml
<changeSet id="001" author="khushal" splitStatements="false">
    <sqlFile path="../../week2/sql/create-audit-log.sql"
             relativeToChangelogFile="false"
             encoding="UTF-8"
             splitStatements="false"/>
</changeSet>
```

Use `<sqlFile>` when:
- The SQL is long (functions, procedures, complex migrations)
- A DBA writes the SQL and a developer wraps it in Liquibase
- You want the SQL to be separately reviewable in Git

The file (`create-audit-log.sql`) contains plain SQL — no Liquibase markers needed. It's just SQL.

`relativeToChangelogFile`:
- `true` → path is relative to the XML changelog file
- `false` → path is relative to the Liquibase working directory (safer with `<sqlFile>`)

---

## `runOnChange="true"` — For Managed DB Objects

```xml
<changeSet id="001" author="khushal" runOnChange="true" splitStatements="false">
    <sql>
        CREATE OR REPLACE VIEW v_product_catalog AS
        SELECT ...;
    </sql>
</changeSet>
```

`runOnChange="true"` tells Liquibase: "if this changeset's content changes, re-run it."

This is appropriate for:
- **Views** (`CREATE OR REPLACE VIEW`)
- **Stored functions** (`CREATE OR REPLACE FUNCTION`)
- **Computed columns or policies** that evolve with business logic

**Never use `runOnChange` for:**
- `CREATE TABLE` — running it again will fail (table exists)
- `ALTER TABLE` — re-running would double-apply the change
- `INSERT` — would duplicate data

---

## Views in This Project

After today's changelog, you have two views:

```sql
-- Summary of orders with user info and item count
SELECT * FROM v_order_summary;

-- Active products with category name
SELECT * FROM v_product_catalog;
```

Try querying them:
```bash
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT * FROM v_product_catalog;"
```

---

## Running It

```bash
docker compose run --rm liquibase update

# Verify views exist
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dv"

# Test the function
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT calculate_order_total(1);"

# Check triggers
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT trigger_name, event_manipulation FROM information_schema.triggers WHERE event_object_table = 'users';"
```

---

## Key Takeaways

- `<sql>` for anything Liquibase doesn't have a built-in type for: views, functions, triggers
- **Always** set `splitStatements="false"` for stored procedures and functions
- `<sqlFile>` keeps long SQL out of the changelog — better for DBA review and Git diffs
- `runOnChange="true"` only for `CREATE OR REPLACE` objects (views, functions) — never for DDL
- In XML, use `&lt;` for `<` in WHERE clauses — or just switch to YAML/SQL format

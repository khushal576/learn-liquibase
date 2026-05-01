# Week 2, Day 4 — Modifying Column Types and Constraints

## Hands-On File
Open: `week2/changelogs/day4-modify-types.xml`

---

## Change Types Covered Today

| Change Type | What It Does |
|-------------|-------------|
| `modifyDataType` | Changes the data type of an existing column |
| `addDefaultValue` | Adds a DEFAULT to an existing column |
| `dropDefaultValue` | Removes a DEFAULT from a column |
| `addNotNullConstraint` | Makes an existing nullable column NOT NULL |
| `dropNotNullConstraint` | Makes an existing NOT NULL column nullable |

---

## `modifyDataType` — Widening vs Narrowing

```xml
<modifyDataType tableName="users"
                columnName="phone"
                newDataType="VARCHAR(30)"/>
```

### Safe Changes (widening)
| From | To | Safe? |
|------|----|-------|
| `VARCHAR(50)` | `VARCHAR(100)` | Yes |
| `INT` | `BIGINT` | Yes |
| `NUMERIC(10,2)` | `NUMERIC(14,4)` | Yes |
| `TEXT` | `VARCHAR(500)` | Depends on existing data |

### Risky Changes (narrowing or type change)
| From | To | Risk |
|------|----|------|
| `VARCHAR(100)` | `VARCHAR(50)` | Fails if any row > 50 chars |
| `BIGINT` | `INT` | Fails if any value > 2,147,483,647 |
| `TEXT` | `VARCHAR(100)` | Fails if any row > 100 chars |
| `NUMERIC` | `INT` | Truncates decimals — data loss |

**Before narrowing:** Always check:
```sql
SELECT MAX(LENGTH(column_name)) FROM table_name;
SELECT MAX(column_name) FROM table_name;
```

### Changing Multiple Columns

You can have multiple `modifyDataType` in one changeset:
```xml
<changeSet id="001" author="khushal">
    <modifyDataType tableName="products"   columnName="price"      newDataType="NUMERIC(14,4)"/>
    <modifyDataType tableName="line_items" columnName="unit_price" newDataType="NUMERIC(14,4)"/>
    <modifyDataType tableName="orders"     columnName="total"      newDataType="NUMERIC(14,4)"/>
</changeSet>
```

Group related changes — here we're changing the precision of all monetary columns together. They belong together because they're part of the same business decision.

---

## `addDefaultValue` and `dropDefaultValue`

```xml
<!-- Add a default to a column that doesn't have one -->
<addDefaultValue tableName="users"
                 columnName="updated_at"
                 defaultValueComputed="CURRENT_TIMESTAMP"/>

<!-- Remove a default -->
<dropDefaultValue tableName="users"
                  columnName="updated_at"
                  columnDataType="TIMESTAMP"/>
```

Default value types:

| Attribute | Example |
|-----------|---------|
| `defaultValue` | `defaultValue="ACTIVE"` |
| `defaultValueNumeric` | `defaultValueNumeric="0"` |
| `defaultValueBoolean` | `defaultValueBoolean="true"` |
| `defaultValueDate` | `defaultValueDate="2024-01-01"` |
| `defaultValueComputed` | `defaultValueComputed="CURRENT_TIMESTAMP"` |

---

## The Full NOT NULL Addition Pattern

Adding NOT NULL to a column with existing data requires 3 changesets (or 3 changes in one changeset):

```xml
<changeSet id="001" author="khushal">
    <!-- 1. Add default so future inserts don't fail -->
    <addDefaultValue tableName="users"
                     columnName="updated_at"
                     defaultValueComputed="CURRENT_TIMESTAMP"/>

    <!-- 2. Backfill NULLs in existing rows -->
    <update tableName="users">
        <column name="updated_at" valueComputed="created_at"/>
        <where>updated_at IS NULL</where>
    </update>

    <!-- 3. Now safe to enforce NOT NULL -->
    <addNotNullConstraint tableName="users"
                          columnName="updated_at"
                          columnDataType="TIMESTAMP"/>
</changeSet>
```

**Why `columnDataType` is required on `addNotNullConstraint`:**
PostgreSQL needs to know the type when adding constraints in some versions. Always include it.

---

## Common Mistake: Skipping the Backfill

```xml
<!-- WRONG — will fail if any row has NULL -->
<addNotNullConstraint tableName="users" columnName="updated_at" columnDataType="TIMESTAMP"/>
```

Error you'll see:
```
ERROR: column "updated_at" of relation "users" contains null values
```

Always run this check before adding NOT NULL:
```sql
SELECT COUNT(*) FROM users WHERE updated_at IS NULL;
```

If it returns > 0, backfill first.

---

## Large Table Consideration

For tables with millions of rows:
- `addNotNullConstraint` takes a full table lock in PostgreSQL
- Use PostgreSQL's `NOT VALID` constraint pattern for large tables:

```xml
<sql>
    -- Add constraint without validating existing rows (fast, no lock)
    ALTER TABLE users
        ADD CONSTRAINT nn_users_updated_at
        CHECK (updated_at IS NOT NULL) NOT VALID;

    -- Validate existing rows separately (acquires weaker ShareUpdateExclusiveLock)
    ALTER TABLE users VALIDATE CONSTRAINT nn_users_updated_at;
</sql>
```

This is PostgreSQL-specific, so use `<sql>` instead of `<addNotNullConstraint>`.

---

## Running It

```bash
docker compose run --rm liquibase update

# Check the users table structure
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d users"

# Verify updated_at is NOT NULL now
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT username, updated_at FROM users LIMIT 5;"
```

---

## Key Takeaways

- Always check data before narrowing a column type — `MAX(LENGTH(...))` is your friend
- Group related type changes together in one changeset
- NOT NULL pattern: `addDefaultValue` → backfill UPDATE → `addNotNullConstraint`
- Always provide `columnDataType` on `addNotNullConstraint`
- For large tables, use PostgreSQL's `NOT VALID` → `VALIDATE CONSTRAINT` pattern to avoid long locks

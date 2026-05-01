# Week 2, Day 2 — Constraints and Indexes

## Hands-On File
Open: `week2/changelogs/day2-constraints-indexes.xml`

---

## Change Types Covered Today

| Change Type | What It Does |
|-------------|-------------|
| `addUniqueConstraint` | Named unique constraint (single or composite) |
| `dropUniqueConstraint` | Removes a unique constraint by name |
| `addNotNullConstraint` | Enforces NOT NULL on an existing column |
| `dropNotNullConstraint` | Makes a column nullable again |
| `addDefaultValue` | Adds a default to an existing column |
| `createIndex` | Creates an index (supports composite and unique) |
| `dropIndex` | Removes an index by name |

---

## Constraint vs Index — What's the Difference?

| | Constraint | Index |
|-|------------|-------|
| Purpose | Enforce a rule (unique, not-null, FK) | Speed up queries |
| Named? | Yes — always give it a meaningful name | Yes |
| Visible in schema? | Yes, as a constraint | As an index only |
| Best for | Data integrity | Query performance |

A unique constraint **implicitly creates a unique index**. So you can use either to enforce uniqueness — but constraints are more descriptive and show up in `\d tablename` output.

---

## Composite Unique Constraint

```xml
<addUniqueConstraint
    tableName="line_items"
    columnNames="order_id, product_id"
    constraintName="uq_line_items_order_product"/>
```

This means: the **combination** of `order_id + product_id` must be unique.
A product can appear in many orders, and an order can have many products — but the same product can't appear twice in the same order.

---

## The Safe NOT NULL Addition Pattern

You **cannot** add NOT NULL to a column that already has NULL rows. PostgreSQL will error.

The 3-step safe pattern (seen in changeset `w2-day2-006`):

```
Step 1: Add a default value (covers future inserts)
Step 2: Backfill existing NULLs (UPDATE ... WHERE col IS NULL)
Step 3: Add the NOT NULL constraint
```

```xml
<!-- Step 1 -->
<addDefaultValue tableName="products" columnName="stock_quantity" defaultValueNumeric="0"/>

<!-- Step 2 -->
<sql>UPDATE products SET stock_quantity = 0 WHERE stock_quantity IS NULL;</sql>

<!-- Step 3 -->
<addNotNullConstraint tableName="products" columnName="stock_quantity" columnDataType="INT"/>
```

---

## Composite Index

```xml
<createIndex tableName="orders" indexName="idx_orders_user_status">
    <column name="user_id"/>
    <column name="status"/>
</createIndex>
```

A composite index covers queries that filter on **both** columns or just the **first** column.

```sql
-- Uses the index (filters on user_id = first column)
SELECT * FROM orders WHERE user_id = 5;

-- Also uses the index (both columns)
SELECT * FROM orders WHERE user_id = 5 AND status = 'PAID';

-- Does NOT use the index (skips first column)
SELECT * FROM orders WHERE status = 'PAID';
```

Rule: **put the most selective column first** in the index definition.

---

## Partial Index

A partial index only indexes rows matching a `WHERE` clause. Liquibase's `<createIndex>` doesn't support partial indexes (it's PostgreSQL-specific), so use `<sql>`:

```xml
<sql>
    CREATE INDEX idx_users_active_email
        ON users(email)
        WHERE status = 'ACTIVE';
</sql>
```

Benefits:
- Much smaller than a full index (only indexes active users, not deleted/inactive)
- Faster to maintain on writes
- Only useful when your query always includes that WHERE condition

---

## Naming Convention for Constraints and Indexes

Always use descriptive names — they show up in error messages and `\d` output.

| Type | Pattern | Example |
|------|---------|---------|
| Primary key | `pk_tablename` | `pk_users` |
| Foreign key | `fk_table_reference` | `fk_orders_user` |
| Unique constraint | `uq_table_columns` | `uq_line_items_order_product` |
| Check constraint | `chk_table_rule` | `chk_orders_status` |
| Index | `idx_table_columns` | `idx_orders_user_status` |

---

## Running It

```bash
docker compose run --rm liquibase update

# Check constraints on line_items
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d line_items"

# List all indexes
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\di"
```

---

## Key Takeaways

- Named constraints are better than anonymous ones — always name them
- Composite unique constraint: `columnNames="col1, col2"`
- Adding NOT NULL to existing column requires: default → backfill → constraint (3 steps)
- Column order in composite indexes matters — most selective first
- Partial indexes are powerful but PostgreSQL-specific — use `<sql>` for them
- Duplicate indexes waste disk space and slow writes — clean them up (day2-007)

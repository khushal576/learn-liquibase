# Week 2, Day 3 — Data Migrations

## Hands-On File
Open: `week2/changelogs/day3-data-migrations.xml`

---

## Change Types Covered Today

| Change Type | What It Does |
|-------------|-------------|
| `insert` | Inserts one row |
| `update` | Updates rows matching a WHERE clause |
| `delete` | Deletes rows matching a WHERE clause |
| `loadData` | Bulk insert from a CSV file |
| `loadUpdateData` | Upsert (insert or update) from a CSV file |

---

## Reference Data vs Test Data

This is a critical distinction:

| Type | What It Is | Context? | Example |
|------|-----------|----------|---------|
| **Reference data** | Data the app requires to function | No context (run everywhere) | Country codes, status enums, product categories |
| **Test/seed data** | Fake data for development/testing | `context="dev"` | Fake users, test orders |

Today's `categories` insert (`w2-day3-001`) has **no context** — categories are required in all environments. The `loadData` for products (`w2-day3-004`) has `context="dev"` — it's test data only.

---

## The `<insert>` Change Type

```xml
<insert tableName="categories">
    <column name="name" value="Electronics"/>
    <column name="slug" value="electronics"/>
</insert>
```

Column value types:

| Attribute | Use For |
|-----------|---------|
| `value` | String literals |
| `valueNumeric` | Numbers |
| `valueBoolean` | true/false |
| `valueDate` | Date literals: `2024-01-15` |
| `valueComputed` | SQL expression: `CURRENT_TIMESTAMP` |

---

## The `<update>` Change Type

```xml
<update tableName="users">
    <column name="status" value="INACTIVE"/>
    <where>is_active = false</where>
</update>
```

The `<where>` clause is raw SQL (no `WHERE` keyword — Liquibase adds it).

**XML special characters in WHERE clauses:**

| Character | XML escape |
|-----------|-----------|
| `<` | `&lt;` |
| `>` | `&gt;` |
| `&` | `&amp;` |
| `"` | `&quot;` |

So `WHERE age < 18` becomes:
```xml
<where>age &lt; 18</where>
```

In YAML and SQL format you don't need escaping:
```yaml
where: "age < 18"
```

---

## The `<delete>` Change Type

```xml
<delete tableName="orders">
    <where>status = 'CANCELLED' AND created_at &lt; NOW() - INTERVAL '1 year'</where>
</delete>
```

**CRITICAL:** Delete rollbacks cannot recover data. The only real rollback is a database backup.

Best practices for delete migrations:
1. Always backup the database first: `pg_dump learndb > backup.sql`
2. Preview how many rows will be deleted: `SELECT COUNT(*) FROM orders WHERE ...`
3. Consider archiving instead of deleting: `INSERT INTO orders_archive SELECT * FROM orders WHERE ...; DELETE ...`
4. Write an empty `<rollback/>` tag with a comment explaining why recovery isn't possible

---

## `<loadData>` — Bulk Insert from CSV

```xml
<loadData tableName="products"
          file="../../week2/sql/products-seed.csv"
          separator=","
          encoding="UTF-8">
    <column name="name"           type="STRING"/>
    <column name="price"          type="NUMERIC"/>
    <column name="stock_quantity" type="NUMERIC"/>
</loadData>
```

The CSV file (`products-seed.csv`):
```
name,description,price,stock_quantity
MacBook Air M3,Apple MacBook Air,1299.99,30
Dell XPS 15,Dell XPS 15 inch,1599.99,20
```

Type mappings for `<column type>`:

| Liquibase type | Maps to |
|----------------|---------|
| `STRING` | VARCHAR / TEXT |
| `NUMERIC` | NUMERIC / DECIMAL |
| `BOOLEAN` | BOOLEAN |
| `DATE` | DATE |
| `DATETIME` | TIMESTAMP |
| `SKIP` | Ignore this CSV column |

---

## `<loadUpdateData>` — Upsert from CSV

```xml
<loadUpdateData tableName="categories"
                file="../../week2/sql/categories-seed.csv"
                separator=","
                primaryKey="slug">
    <column name="name" type="STRING"/>
    <column name="slug" type="STRING"/>
</loadUpdateData>
```

- If a row with that `primaryKey` value exists → **UPDATE**
- If not → **INSERT**

Use this for reference data that you want to keep in sync across environments. Safe to run multiple times — it won't duplicate rows.

---

## Backfill Migration Pattern

When you add a new column and need to populate it for existing rows:

```xml
<changeSet id="backfill-001" author="khushal">
    <!-- 1. Add the column (nullable first) -->
    <addColumn tableName="products">
        <column name="category_id" type="BIGINT"/>
    </addColumn>

    <!-- 2. Populate based on existing data -->
    <sql>
        UPDATE products SET category_id = (
            SELECT id FROM categories WHERE slug = 'electronics'
        )
        WHERE name ILIKE '%laptop%';
    </sql>

    <!-- 3. Optionally make it NOT NULL after backfill -->
    <!-- Only if ALL rows were filled — otherwise this will fail -->
</changeSet>
```

---

## Running It

```bash
# Without contexts — only reference data (categories)
docker compose run --rm liquibase update

# With dev context — includes CSV seed data
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --contexts=dev \
  update

# Verify
docker exec -it liquibase_db psql -U liquibase -d learndb -c "SELECT * FROM categories;"
docker exec -it liquibase_db psql -U liquibase -d learndb -c "SELECT name, price FROM products;"
```

---

## Key Takeaways

- Reference data: no context. Test/fake data: `context="dev"`
- XML `<where>` needs escaping for `< > & "` — use YAML/SQL format to avoid this
- Delete rollback is impossible without a backup — always backup before running delete migrations
- `loadData` = insert only; `loadUpdateData` = upsert (safe to re-run)
- Backfill pattern: add nullable column → populate → optionally enforce NOT NULL

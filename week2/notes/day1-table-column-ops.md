# Week 2, Day 1 — Table and Column Operations

## Hands-On File
Open: `week2/changelogs/day1-table-column-ops.xml`

---

## Change Types Covered Today

| Change Type | What It Does |
|-------------|-------------|
| `createTable` | Creates a new table |
| `addColumn` | Adds one or more columns to an existing table |
| `dropColumn` | Removes a column |
| `renameColumn` | Renames a column |
| `renameTable` | Renames a table |
| `addForeignKeyConstraint` | Adds a FK between two tables |
| `dropForeignKeyConstraint` | Removes a FK |

---

## Self-Referencing Foreign Key

The `categories` table has a `parent_id` that references its own `id` — this allows a tree structure (parent categories).

```xml
<createTable tableName="categories">
    <column name="id" .../>
    <column name="parent_id" type="BIGINT"/>  <!-- nullable — root categories have no parent -->
</createTable>

<!-- Self-reference: FK to same table -->
<addForeignKeyConstraint
    baseTableName="categories"
    baseColumnNames="parent_id"
    constraintName="fk_categories_parent"
    referencedTableName="categories"
    referencedColumnNames="id"/>
```

The FK must be added AFTER the table exists (even though it references the same table — Liquibase handles it correctly).

---

## Safe Column Drop Pattern

**Never just drop a column that has data.** The correct pattern:

```
1. Add the replacement column
2. Copy/transform data from old → new column (UPDATE)
3. Drop the old column
```

In today's changeset (`w2-day1-004`), we replaced `is_active BOOLEAN` with `status VARCHAR(20)`:

```xml
<!-- Step 1: Add replacement -->
<addColumn tableName="users">
    <column name="status" type="VARCHAR(20)" defaultValue="ACTIVE"/>
</addColumn>

<!-- Step 2: Backfill -->
<update tableName="users">
    <column name="status" value="INACTIVE"/>
    <where>is_active = false</where>
</update>

<!-- Step 3: Drop old -->
<dropColumn tableName="users" columnName="is_active"/>
```

And the rollback does the exact reverse — adds `is_active` back, copies data, drops `status`.

---

## addColumn with Multiple Columns

You can add several columns in one changeset:

```xml
<addColumn tableName="users">
    <column name="phone"         type="VARCHAR(20)"/>
    <column name="date_of_birth" type="DATE"/>
    <column name="updated_at"    type="TIMESTAMP"/>
</addColumn>
```

Rollback must drop them all:
```xml
<rollback>
    <dropColumn tableName="users">
        <column name="phone"/>
        <column name="date_of_birth"/>
        <column name="updated_at"/>
    </dropColumn>
</rollback>
```

---

## dropForeignKeyConstraint Before dropColumn

If a column has a FK constraint, you must drop the FK **before** dropping the column.
Liquibase won't do this automatically — the rollback must be explicit:

```xml
<rollback>
    <!-- 1. Drop FK first -->
    <dropForeignKeyConstraint
        baseTableName="products"
        constraintName="fk_products_category"/>
    <!-- 2. Then drop column -->
    <dropColumn tableName="products" columnName="category_id"/>
</rollback>
```

---

## Running It

```bash
cd docker

# Apply week1 + week2 day1
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --changeLogFile=changelog/../../week2/changelogs/master.xml \
  update

# Verify schema changes
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d users"
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d categories"
```

---

## Key Takeaways

- Always drop FKs before dropping columns or tables
- Add replacement column → backfill → drop old: the safe column migration pattern
- `renameTable` cascades to FKs automatically in PostgreSQL but not all DBs — test it
- A changeset should do ONE logical operation — don't mix unrelated column changes

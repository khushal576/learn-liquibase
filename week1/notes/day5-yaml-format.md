# Day 5 — YAML Format & Foreign Keys

## Hands-On File
Open: `week1/changelogs/day5-create-products-yaml.yaml`

---

## Why YAML Format?

YAML is the most **human-readable** format for complex changesets. When you have many columns with many options, YAML's indentation makes it easier to scan than XML angle brackets.

```yaml
databaseChangeLog:
  - changeSet:
      id: 001
      author: khushal
      changes:
        - createTable:
            tableName: products
            columns:
              - column:
                  name: id
                  type: BIGINT
```

Compare to XML:
```xml
<changeSet id="001" author="khushal">
    <createTable tableName="products">
        <column name="id" type="BIGINT">
        </column>
    </createTable>
</changeSet>
```

Same result. YAML just reads more naturally for deeply nested structures.

---

## YAML Changelog Structure

```yaml
databaseChangeLog:           # root element (required)

  - changeSet:               # one changeset
      id: "001"
      author: khushal
      comment: "optional description"
      context: dev           # optional
      changes:               # list of changes
        - createTable: ...
        - addColumn: ...
      rollback:              # optional rollback
        - dropTable: ...

  - changeSet:               # another changeset
      id: "002"
      ...
```

---

## addForeignKeyConstraint

This is important — always add FKs as a **separate change** from `createTable` in XML/YAML:

```yaml
- addForeignKeyConstraint:
    baseTableName: order_items        # the table with the FK column
    baseColumnNames: order_id         # the FK column
    constraintName: fk_order_items_order   # name for the constraint
    referencedTableName: orders       # the table being referenced
    referencedColumnNames: id         # the referenced column
    onDelete: CASCADE                 # optional: CASCADE, SET NULL, RESTRICT
    onUpdate: RESTRICT                # optional
```

Why separate? Because it's a separate database operation. Also, if the referenced table doesn't exist yet, you need ordering control — and keeping FK additions separate makes that easier.

---

## Rollback for Multiple Changes

When a changeset has multiple changes, the rollback must undo ALL of them, in reverse order:

```yaml
- changeSet:
    id: day5-002
    changes:
      - createTable:
          tableName: order_items
          ...
      - addForeignKeyConstraint:
          ...
      - addForeignKeyConstraint:
          ...
    rollback:
      # Rollback drops FKs automatically when table is dropped
      - dropTable:
          tableName: order_items
```

For `createTable`, dropping the table automatically removes its FKs, so one `dropTable` is enough for rollback.

---

## YAML Gotchas

**1. Quote numeric IDs**
```yaml
id: "001"    # safe
id: 001      # YAML parses this as integer 1 — may cause issues
```

**2. Indentation must be consistent**
YAML uses spaces (not tabs). One wrong indent breaks the whole file.

**3. Boolean values**
```yaml
nullable: false    # correct
nullable: False    # also works in YAML but inconsistent
nullable: "false"  # wrong — this is the string "false"
```

---

## Running It

```bash
docker compose run --rm liquibase

docker exec -it liquibase_db psql -U liquibase -d learndb

# Verify all tables:
\dt

# Check foreign keys on order_items:
\d order_items

# See all 5 changelogs applied:
SELECT id, filename FROM databasechangelog ORDER BY orderexecuted;
```

---

## Key Takeaways

- YAML format is best for complex changesets with many columns or nested options
- `addForeignKeyConstraint` is a separate change type from `createTable`
- Rollback must undo ALL changes in a changeset — in reverse order
- YAML is strict about indentation — use a linter or IDE plugin (YAML extension in VSCode)

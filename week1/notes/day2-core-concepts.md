# Day 2 — Core Concepts & Architecture

## How Liquibase Works (Step by Step)

When you run `liquibase update`, this is exactly what happens internally:

```
1. Liquibase reads your changelog file
2. It locks DATABASECHANGELOGLOCK (so no other process can run at same time)
3. It reads DATABASECHANGELOG to see what's already been applied
4. It compares pending changesets vs already-applied ones
5. It runs each pending changeset IN ORDER
6. It records each applied changeset in DATABASECHANGELOG
7. It releases the lock
```

---

## The Changelog File

The changelog is the entry point — it's just a file that contains (or references) changesets.

```
master.xml  ← root changelog
  ├── day3-create-users.xml
  ├── day4-create-orders.sql
  └── day5-create-products.yaml
```

You can write it in 4 formats — they are all equivalent:

| Format | Best For |
|--------|----------|
| **XML** | Most explicit, best IDE support |
| **YAML** | Most readable for complex changes |
| **SQL** | Teams that prefer raw SQL, easy migration from manual scripts |
| **JSON** | Programmatically generated changelogs |

---

## The Changeset — Most Important Unit

A changeset is identified by **3 things together**:
```
id + author + filename = unique key
```

Example in XML:
```xml
<changeSet id="001" author="khushal">
    <createTable tableName="users"> ... </createTable>
</changeSet>
```

Example in SQL format:
```sql
--changeset khushal:001
CREATE TABLE users (...);
```

**CRITICAL RULE:** Once a changeset is deployed, NEVER change its content.
Liquibase stores an MD5 hash of each changeset. If you edit it, Liquibase throws an error on next run.

---

## The DATABASECHANGELOG Table

Liquibase auto-creates this table in your database. It looks like this:

| Column | What it stores |
|--------|---------------|
| `ID` | The changeset id |
| `AUTHOR` | The changeset author |
| `FILENAME` | The changelog file path |
| `DATEEXECUTED` | When it was applied |
| `ORDEREXECUTED` | Sequence number |
| `MD5SUM` | Hash of the changeset content |
| `EXECTYPE` | EXECUTED / MARK_RAN / RERAN / FAILED |
| `DESCRIPTION` | Auto-generated description of the change |
| `TAG` | If you tagged this state |

Run this after `liquibase update` to see it:
```sql
SELECT id, author, filename, dateexecuted, exectype
FROM databasechangelog
ORDER BY orderexecuted;
```

---

## The DATABASECHANGELOGLOCK Table

This table has one row. Its `LOCKED` column is either `true` or `false`.

- Before running: Liquibase sets `LOCKED = true`
- After running: Liquibase sets `LOCKED = false`

**Problem:** If Liquibase crashes mid-run, the lock stays. Fix it with:
```bash
liquibase releaseLocks
```

---

## Important Changeset Attributes

```xml
<changeSet
    id="001"
    author="khushal"
    runOnChange="false"    <!-- default: re-run if content changes (breaks MD5 rule) -->
    runAlways="false"      <!-- default: run every time regardless of history -->
    context="dev"          <!-- only run when --contexts=dev is passed -->
    labels="feature-x"    <!-- like contexts but for different filtering logic -->
    failOnError="true"     <!-- default: stop if this changeset fails -->
>
```

`runAlways="true"` is useful for things like stored procedures that need to be recreated each deploy.

---

## Supported Change Types (Preview)

Liquibase has 100+ built-in change types. Common ones you'll use:

**Table operations:** `createTable`, `dropTable`, `renameTable`
**Column operations:** `addColumn`, `dropColumn`, `renameColumn`, `modifyDataType`
**Constraints:** `addForeignKeyConstraint`, `addUniqueConstraint`, `addNotNullConstraint`
**Indexes:** `createIndex`, `dropIndex`
**Data:** `insert`, `update`, `delete`, `loadData` (from CSV)
**Raw SQL:** `sql`, `sqlFile`

---

## Today's Exercise

Draw a diagram of this flow on paper:

```
Developer writes changeset → pushes to Git → CI/CD runs liquibase update
→ Liquibase checks DATABASECHANGELOG → applies new changesets → records them
```

This mental model is everything. The rest of the course is just filling in the details.

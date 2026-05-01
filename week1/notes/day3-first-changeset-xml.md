# Day 3 — Your First Changeset (XML Format)

## Hands-On File
Open: `week1/changelogs/day3-create-users-xml.xml`

---

## XML Changelog Structure

Every XML changelog starts with the same boilerplate header:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.27.xsd">

    <!-- your changeSets go here -->

</databaseChangeLog>
```

You don't need to memorize this — just copy it as a template.

---

## createTable — Breaking It Down

```xml
<changeSet id="day3-001" author="khushal">

    <createTable tableName="users">

        <!-- Primary key column -->
        <column name="id" type="BIGINT" autoIncrement="true">
            <constraints primaryKey="true" nullable="false"/>
        </column>

        <!-- A column with a unique constraint -->
        <column name="email" type="VARCHAR(100)">
            <constraints unique="true" nullable="false"/>
        </column>

        <!-- A column with a default value (function call) -->
        <column name="created_at" type="TIMESTAMP"
                defaultValueComputed="CURRENT_TIMESTAMP">
            <constraints nullable="false"/>
        </column>

        <!-- A boolean column with a default -->
        <column name="is_active" type="BOOLEAN"
                defaultValueBoolean="true">
            <constraints nullable="false"/>
        </column>

    </createTable>

    <!-- Explicit rollback: what to do on `liquibase rollback` -->
    <rollback>
        <dropTable tableName="users"/>
    </rollback>

</changeSet>
```

### Column `defaultValue` types

| Attribute | Use For |
|-----------|---------|
| `defaultValue` | String values |
| `defaultValueNumeric` | Numbers |
| `defaultValueBoolean` | true/false |
| `defaultValueDate` | Date literals |
| `defaultValueComputed` | SQL functions like `CURRENT_TIMESTAMP` |

---

## Running It

```bash
# From the docker/ directory
docker compose up postgres -d

# Run the migration
docker compose run --rm liquibase

# Connect and verify
docker exec -it liquibase_db psql -U liquibase -d learndb

# Inside psql:
\dt                  -- list all tables
\d users             -- describe the users table
SELECT * FROM databasechangelog;
\q
```

---

## What to Look For in DATABASECHANGELOG

After running, query the tracking table:
```sql
SELECT id, author, filename, md5sum, exectype
FROM databasechangelog;
```

Notice the `MD5SUM` column. Now go edit something in `day3-create-users-xml.xml` (like changing `VARCHAR(50)` to `VARCHAR(60)`) and run `liquibase update` again.

You will see this error:
```
Validation Failed:
  1 changesets check sum
    day3-create-users-xml.xml::day3-001::khushal was: ...
    but is now: ...
```

This is Liquibase protecting you from accidentally modifying a deployed change. **Undo your edit.**

---

## The Right Way to Modify a Deployed Table

Never edit the changeset. Add a NEW one:

```xml
<!-- WRONG: editing day3-001 -->

<!-- RIGHT: add a new changeset -->
<changeSet id="day3-002" author="khushal">
    <modifyDataType tableName="users"
                    columnName="username"
                    newDataType="VARCHAR(60)"/>
</changeSet>
```

---

## Rollback Practice

```bash
# Tag the current state first
docker compose run --rm liquibase tag --tag=before-day3

# Apply day3 changes
docker compose run --rm liquibase update

# Now roll back to before
docker compose run --rm liquibase rollback --tag=before-day3

# The users table is gone again — verify:
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"
```

---

## Key Takeaways

- XML format is verbose but explicit — nothing is hidden
- `id + author + filename` = the unique identity of a changeset
- MD5 hash enforces immutability of deployed changesets
- Always write a `<rollback>` block — even if Liquibase can auto-generate it, explicit is safer

# Week 4, Day 2 — Preconditions

## Hands-On File
Open: `week4/changelogs/day2-preconditions.xml`

---

## What Are Preconditions?

A precondition is a check that runs BEFORE a changeset executes. If the check fails, Liquibase decides what to do based on `onFail` and `onError`.

Use cases:
- Make changesets idempotent (safe to run on any DB, even partially-migrated ones)
- Guard data inserts against duplicates
- Ensure a dependency (table, column, row) exists before referencing it
- Protect against accidentally running a migration on the wrong database

---

## `onFail` and `onError` Options

```xml
<preConditions onFail="HALT" onError="HALT">
```

| Value | Behavior |
|-------|----------|
| `HALT` | Stop entire migration and report failure (default) |
| `CONTINUE` | Skip this changeset and continue with the next |
| `MARK_RAN` | Mark this changeset as run (in DATABASECHANGELOG) without executing it |
| `WARN` | Log a warning and continue executing the changeset anyway |

| Setting | `onFail` | `onError` |
|---------|----------|-----------|
| Table already exists (you'd get duplicate) | `MARK_RAN` | — |
| Required data is missing (you need it) | `HALT` | `HALT` |
| Optional dependency | `WARN` | `WARN` |

---

## All Precondition Types

### Schema Object Checks
```xml
<tableExists tableName="users"/>
<tableExists tableName="users" schemaName="public"/>

<columnExists tableName="users" columnName="email"/>

<indexExists tableName="users" indexName="idx_users_email"/>

<foreignKeyConstraintExists
    foreignKeyTableName="orders"
    foreignKeyName="fk_orders_user"/>

<primaryKeyExists tableName="users" primaryKeyName="pk_users"/>

<sequenceExists sequenceName="users_id_seq"/>

<viewExists viewName="v_order_summary"/>
```

### Data Checks
```xml
<!-- SQL must return the expectedResult value -->
<sqlCheck expectedResult="1">
    SELECT COUNT(*) FROM categories WHERE slug = 'electronics'
</sqlCheck>

<sqlCheck expectedResult="0">
    SELECT COUNT(*) FROM users WHERE email = 'admin@example.com'
</sqlCheck>
```

### Database Checks
```xml
<!-- Only run on PostgreSQL -->
<dbms type="postgresql"/>

<!-- Only run on PostgreSQL or MySQL -->
<dbms type="postgresql,mysql"/>

<!-- Only run on specific Liquibase version -->
<runningAs username="liquibase"/>
```

### Logic Operators
```xml
<!-- AND: all conditions must pass -->
<and>
    <tableExists tableName="users"/>
    <columnExists tableName="users" columnName="email"/>
</and>

<!-- OR: any condition must pass -->
<or>
    <tableExists tableName="orders"/>
    <tableExists tableName="legacy_orders"/>
</or>

<!-- NOT: condition must be false -->
<not>
    <tableExists tableName="product_tags"/>
</not>
```

---

## Idempotent Changeset Pattern

The most common use of preconditions is making changesets safe to re-run:

```xml
<!-- Without precondition: fails if table already exists -->
<changeSet id="001" author="khushal">
    <createTable tableName="product_tags"> ... </createTable>
</changeSet>

<!-- With precondition: safe to run on any database state -->
<changeSet id="001" author="khushal">
    <preConditions onFail="MARK_RAN">
        <not><tableExists tableName="product_tags"/></not>
    </preConditions>
    <createTable tableName="product_tags"> ... </createTable>
</changeSet>
```

When to use this:
- When onboarding a DB that may have partial migrations
- When a changeset might have been run manually in some environments
- For reference data inserts that might already exist

When NOT to use this:
- As a substitute for proper changelog management
- To silently skip changes that should always run
- In fresh deployments where you control the full lifecycle

---

## Changelog-Level Preconditions

Preconditions can also go at the top of the changelog (not inside a changeset), applying to the whole file:

```xml
<databaseChangeLog ...>

    <!-- Fail the entire changelog if not running against PostgreSQL -->
    <preConditions onFail="HALT">
        <dbms type="postgresql"/>
    </preConditions>

    <!-- Warn if running as root (dangerous) -->
    <preConditions onFail="WARN">
        <not><runningAs username="postgres"/></not>
    </preConditions>

    <changeSet id="001" ...>
        ...
    </changeSet>

</databaseChangeLog>
```

---

## Running It

```bash
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week4/changelogs/master.xml \
  update

# Verify product_tags was created
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d product_tags"

# Check the EXECTYPE — precondition skips show as MARK_RAN
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT id, exectype, contexts FROM databasechangelog WHERE filename LIKE '%day2%';"

# Re-run update — preconditions prevent duplicate errors
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week4/changelogs/master.xml \
  update
```

---

## Key Takeaways

- Preconditions run before the changeset SQL — they're guards, not fixes
- `MARK_RAN` is the right `onFail` for "skip if already done"
- `HALT` is the right `onFail` for "this must be true or we can't proceed"
- `sqlCheck` is the most flexible — any query result can be checked
- `dbms` prevents running PostgreSQL-specific SQL on MySQL accidentally
- Changelog-level preconditions protect the whole file
- Don't over-use preconditions — they add complexity; use only when truly needed

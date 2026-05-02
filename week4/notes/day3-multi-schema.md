# Week 4, Day 3 — Multi-Schema Management

## Hands-On File
Open: `week4/changelogs/day3-multi-schema.xml`

---

## Schemas in PostgreSQL

A **schema** is a namespace inside a database. Every table, view, function, and index lives in a schema. The default schema is `public`.

```
Database: learndb
├── Schema: public          ← your main application tables
│   ├── users
│   ├── orders
│   └── products
├── Schema: analytics       ← reporting/metrics tables
│   └── order_metrics
└── Schema: reporting       ← pre-aggregated reports
    └── monthly_sales
```

Benefits of multiple schemas:
- **Separation of concerns**: app tables vs analytics vs audit
- **Access control**: grant read-only on `reporting`, full access on `public`
- **Multi-tenant**: one schema per tenant in the same database
- **Organization**: large systems with hundreds of tables

---

## Referencing Schemas in Liquibase

Most change types accept a `schemaName` attribute:

```xml
<createTable tableName="order_metrics" schemaName="analytics">
    <column name="id" type="BIGINT" autoIncrement="true">
        <constraints primaryKey="true" nullable="false"/>
    </column>
    ...
</createTable>

<createIndex tableName="order_metrics"
             indexName="idx_order_metrics_date"
             schemaName="analytics">
    <column name="metric_date"/>
</createIndex>

<dropTable tableName="order_metrics" schemaName="analytics"/>

<addColumn tableName="order_metrics" schemaName="analytics">
    <column name="currency" type="VARCHAR(3)"/>
</addColumn>
```

For raw SQL, use the fully qualified name:
```xml
<sql>SELECT * FROM analytics.order_metrics;</sql>
<sql>INSERT INTO reporting.monthly_sales ...</sql>
```

---

## Creating Schemas

Liquibase doesn't have a `createSchema` change type. Use `<sql>`:

```xml
<changeSet id="001" author="khushal">
    <sql>CREATE SCHEMA IF NOT EXISTS analytics;</sql>
    <rollback>
        <sql>DROP SCHEMA IF EXISTS analytics CASCADE;</sql>
    </rollback>
</changeSet>
```

`CASCADE` drops everything inside the schema. Use carefully in rollbacks.

---

## `defaultSchemaName` Configuration

Set a default schema so you don't need `schemaName` on every change:

```properties
# liquibase.properties
defaultSchemaName=myapp
```

Now all changes without explicit `schemaName` target the `myapp` schema.

For the `DATABASECHANGELOG` tracking tables, use:
```properties
liquibaseSchemaName=liquibase_metadata   # keep tracking tables in a separate schema
```

---

## Multi-Tenant Pattern: One Schema Per Tenant

A common SaaS pattern where each customer gets their own schema:

```
Database: saas_db
├── Schema: tenant_acme       ← ACME Corp's data
├── Schema: tenant_globex     ← Globex Corp's data
└── Schema: shared            ← shared reference data
```

```xml
<!-- Template changelog applied once per tenant -->
<changeSet id="create-tenant-schema" author="khushal">
    <sql>CREATE SCHEMA IF NOT EXISTS ${tenant_schema};</sql>
    <rollback>
        <sql>DROP SCHEMA IF EXISTS ${tenant_schema} CASCADE;</sql>
    </rollback>
</changeSet>

<changeSet id="create-tenant-users" author="khushal">
    <createTable tableName="users" schemaName="${tenant_schema}">
        <column name="id" type="BIGINT" autoIncrement="true">
            <constraints primaryKey="true" nullable="false"/>
        </column>
        ...
    </createTable>
</changeSet>
```

Run with the tenant name as a property:
```bash
liquibase update -Dtenant_schema=tenant_acme
liquibase update -Dtenant_schema=tenant_globex
```

Liquibase property substitution: `${variable_name}` in changelogs is replaced at runtime.

---

## Cross-Schema Views and Joins

Views can join tables from different schemas:

```xml
<changeSet id="001" author="khushal" splitStatements="false">
    <sql>
        CREATE OR REPLACE VIEW reporting.v_daily_performance AS
        SELECT
            m.metric_date,
            m.total_orders,
            m.total_revenue
        FROM analytics.order_metrics m  -- analytics schema
        ORDER BY m.metric_date DESC;
    </sql>
</changeSet>
```

---

## Permissions Management

```xml
<changeSet id="001" author="khushal">
    <sql>
        -- Read-only access to analytics schema
        GRANT USAGE ON SCHEMA analytics TO reporting_user;
        GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO reporting_user;

        -- Ensure future tables are also accessible
        ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
            GRANT SELECT ON TABLES TO reporting_user;
    </sql>
</changeSet>
```

---

## Running It

```bash
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week4/changelogs/master.xml update

# Verify schemas were created
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT schema_name FROM information_schema.schemata ORDER BY schema_name;"

# List tables in analytics schema
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "\dt analytics.*"

# List tables in reporting schema
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "\dt reporting.*"

# Check cross-schema view
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT * FROM reporting.v_daily_performance LIMIT 5;"
```

---

## Key Takeaways

- Schemas are namespaces — use them to separate app, analytics, and audit tables
- Add `schemaName` attribute to any change type that needs a non-default schema
- Set `defaultSchemaName` in properties to avoid repeating it everywhere
- Keep `DATABASECHANGELOG` in a dedicated schema with `liquibaseSchemaName`
- Use `${variable}` substitution for multi-tenant schema names
- Always `GRANT` appropriate permissions after creating schemas
- `DROP SCHEMA CASCADE` is destructive — always in the rollback, never in the forward change

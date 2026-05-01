# Week 2, Day 7 — Contexts and Labels In Depth

## Hands-On File
Open: `week2/changelogs/day7-contexts-labels.xml`

---

## Contexts — Environment Filtering

A context is a string tag you attach to a changeset. Liquibase only runs it when the active context matches.

### How matching works

| Changeset context | Active `--contexts` | Runs? |
|-------------------|---------------------|-------|
| `context="dev"` | `--contexts=dev` | Yes |
| `context="dev"` | `--contexts=prod` | No |
| `context="dev"` | `--contexts=dev,staging` | Yes |
| `context="dev,staging"` | `--contexts=dev` | Yes (OR logic) |
| *(no context)* | `--contexts=prod` | **Yes** — no context = always runs |
| *(no context)* | *(no --contexts flag)* | Yes |

**Key rule:** A changeset with **no context** runs in every environment, always. Use this for schema changes. Only put `context` on data changesets.

---

## Context Expressions (Advanced)

Beyond simple strings, contexts support boolean expressions:

```xml
<!-- Runs in dev OR staging -->
<changeSet id="001" context="dev,staging">

<!-- Runs in dev AND NOT prod -->
<changeSet id="002" context="dev and not prod">

<!-- Complex expression -->
<changeSet id="003" context="(dev or staging) and feature-x">
```

CLI usage:
```bash
# Simple
liquibase update --contexts=dev

# Multiple
liquibase update --contexts="dev,staging"

# Expression
liquibase update --contexts="dev and feature-x"
```

---

## Contexts in `liquibase.properties`

Instead of passing on every CLI call, set it in the config:

```properties
# liquibase.properties
contexts=dev
```

Then override at runtime:
```bash
# Override just for production run
liquibase update --contexts=prod
```

---

## Labels — Feature Flag Filtering

Labels look like contexts but filter differently. Labels support expressions:

```xml
<changeSet id="001" labels="feature-loyalty-points">
```

Run with:
```bash
liquibase update --labels="feature-loyalty-points"
```

### Labels vs Contexts — The Key Difference

| | Contexts | Labels |
|-|----------|--------|
| Purpose | Environment (dev/staging/prod) | Features / release trains |
| Expression | Simple comma = OR | Full AND/OR/NOT expressions |
| Who sets active value | Ops/CI pipeline (`--contexts`) | Dev team (`--labels`) |
| Typical use | "Only in dev" | "Only when feature X is ready" |

---

## Label Expressions

```bash
# Run changesets with this label
liquibase update --labels="feature-loyalty-points"

# Run changesets with EITHER label
liquibase update --labels="feature-loyalty-points or feature-coupons"

# Run changesets with BOTH labels
liquibase update --labels="feature-x and feature-y"

# Run changesets without a specific label
liquibase update --labels="not beta"
```

On the changeset side:
```xml
<!-- Only run when BOTH labels are active -->
<changeSet id="001" labels="feature-x and feature-y">

<!-- Run when either is active -->
<changeSet id="002" labels="feature-x,feature-y">
```

---

## Combining Contexts AND Labels

```xml
<changeSet id="001"
           context="dev,staging"
           labels="feature-loyalty-points">
```

**Both must match.** This changeset runs only when:
- Active context is `dev` OR `staging`
- AND active label includes `feature-loyalty-points`

CLI:
```bash
liquibase update --contexts=dev --labels="feature-loyalty-points"
```

---

## Real-World Patterns

### Pattern 1: Environment-specific indexes

```xml
<!-- Dev: simple index (small data) -->
<changeSet id="idx-dev" context="dev,staging">
    <createIndex tableName="orders" indexName="idx_orders_created">
        <column name="created_at"/>
    </createIndex>
</changeSet>

<!-- Prod: concurrent index (no table lock) -->
<changeSet id="idx-prod" context="prod">
    <sql>
        CREATE INDEX CONCURRENTLY idx_orders_created ON orders(created_at DESC);
    </sql>
</changeSet>
```

### Pattern 2: Feature flags for schema

```xml
<!-- Schema for new feature — only deploy when team is ready -->
<changeSet id="feature-reviews-schema" labels="feature-product-reviews">
    <createTable tableName="product_reviews"> ... </createTable>
</changeSet>

<!-- Seed data for testing the feature -->
<changeSet id="feature-reviews-seed" context="dev" labels="feature-product-reviews">
    <insert tableName="product_reviews"> ... </insert>
</changeSet>
```

Deploy the schema to prod when ready:
```bash
liquibase update --contexts=prod --labels="feature-product-reviews"
```

### Pattern 3: Rollout stages

```xml
<changeSet id="001" labels="rollout-phase-1">...</changeSet>
<changeSet id="002" labels="rollout-phase-2">...</changeSet>
<changeSet id="003" labels="rollout-phase-3">...</changeSet>
```

```bash
# Deploy in phases
liquibase update --labels="rollout-phase-1"
# ... verify in prod ...
liquibase update --labels="rollout-phase-2"
```

---

## Week 2 Final Exercise

```bash
# 1. Run without any contexts or labels — only required changesets
docker compose run --rm liquibase update

# 2. Run with dev context — adds dev seed data
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --contexts=dev update

# 3. Run with the loyalty points feature label
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --labels="feature-loyalty-points" update

# 4. Run with both context + label
docker compose run --rm liquibase \
  --defaults-file=/liquibase/liquibase.properties \
  --contexts=dev --labels="feature-loyalty-points" update

# 5. Check what ran and with what contexts/labels
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT id, contexts, labels, dateexecuted FROM databasechangelog ORDER BY orderexecuted;"

# 6. Verify loyalty_points table was created
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d loyalty_points"
```

---

## Week 2 Summary — What You've Learned

| Day | Topic | Key Commands |
|-----|-------|-------------|
| 1 | Table/column CRUD | `createTable`, `addColumn`, `dropColumn`, `renameTable` |
| 2 | Constraints and indexes | `addUniqueConstraint`, `createIndex`, `addNotNullConstraint` |
| 3 | Data migrations | `insert`, `update`, `delete`, `loadData`, `loadUpdateData` |
| 4 | Type changes | `modifyDataType`, `addDefaultValue`, `dropNotNullConstraint` |
| 5 | Raw SQL | `<sql>`, `<sqlFile>`, `splitStatements`, `runOnChange` |
| 6 | Changelog organization | `<include>`, `<includeAll>`, directory structure |
| 7 | Environments | `context`, `labels`, expression syntax |

You're ready for Week 3 — Rollbacks, `diff`, `generateChangeLog`, and CI/CD integration.

---

## Key Takeaways

- Contexts = environments (dev/staging/prod) — set by ops/CI
- Labels = features/releases — set by dev teams
- No context on a changeset = runs in ALL environments, always
- `context="dev,staging"` uses OR logic (comma = OR)
- Labels support full boolean expressions: `and`, `or`, `not`
- Combine context + labels for precise control: both must match

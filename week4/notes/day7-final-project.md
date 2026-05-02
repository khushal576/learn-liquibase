# Week 4, Day 7 — Final Project: Full Schema Lifecycle

## Hands-On File
Open: `week4/changelogs/day7-final-project.xml`

---

## What This Final Project Covers

The `day7-final-project.xml` demonstrates every major technique from the course in one real-world feature deployment:

| Technique | Where Used |
|-----------|-----------|
| Preconditions | Guard every changeset |
| Multi-schema | `analytics.recommendation_events` |
| `runOnChange` view | `analytics.v_recommendation_performance` |
| `CREATE INDEX CONCURRENTLY` | `idx_recommendations_user_score` |
| Contexts | `context="dev"` on seed data |
| Labels | `labels="feature-recommendations"` |
| Cross-schema joins | Analytics view joins public schema |
| `onDelete="CASCADE"` FK | Cleans up recommendations when user/product deleted |
| Empty rollback with comment | `post-rename-cleanup` has `<rollback/>` |

---

## The Complete Deployment Workflow

This is the exact sequence you'd run for a real production deployment.

### Step 1: Validate everything

```bash
ARGS="--url=jdbc:postgresql://postgres:5432/learndb --username=liquibase --password=liquibase123"

# Validate changelog syntax
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml validate

# Check what's pending
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml status --verbose

# Verify all rollbacks are valid
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml futureRollbackSQL
```

### Step 2: Preview the SQL

```bash
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml updateSQL
```

Review the output — check for unexpected changes.

### Step 3: Tag the database

```bash
docker compose run --rm liquibase $ARGS \
  tag --tag=pre-week4
```

### Step 4: Apply standard changes (no labels)

```bash
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml update
```

This applies all changesets WITHOUT the `feature-recommendations` label. The recommendations schema is NOT created yet.

```bash
# Verify: recommendations table should NOT exist yet
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='recommendations');"
```

### Step 5: Apply the feature flag

When the team is ready to ship the recommendations feature:

```bash
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml \
  --labels="feature-recommendations" update
```

```bash
# Now the recommendations table should exist
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d recommendations"
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt analytics.*"
```

### Step 6: Apply dev seed data

```bash
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml \
  --contexts=dev \
  --labels="feature-recommendations" update
```

```bash
# Check seed data
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT * FROM recommendations;"
```

### Step 7: Check the analytics view

```bash
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT * FROM analytics.v_recommendation_performance;"
```

### Step 8: Simulate a production rollback

```bash
# Preview what would be undone
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml \
  rollbackSQL --tag=pre-week4

# Execute rollback
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml \
  rollback --tag=pre-week4

# Verify
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\dt"
```

### Step 9: Re-apply to get back to full state

```bash
docker compose run --rm liquibase $ARGS \
  --changeLogFile=week4/changelogs/master.xml \
  --contexts=dev \
  --labels="feature-recommendations" update
```

---

## Final Schema Map

After the complete 4-week course, your database has:

**Public schema:**
- `users` — auth, profile, loyalty_tier, status
- `orders` — with coupon_id, shipping fields, priority
- `line_items` — (renamed from order_items)
- `products` — with category_id, discount_pct, supplier_id, weight_kg
- `categories` — self-referencing tree, url_key + url_slug
- `coupons` — discount codes
- `product_reviews` — ratings and reviews
- `product_tags` — tag-based search
- `wishlist_items` — saved for later
- `notifications` — user notifications
- `user_sessions` — session tracking
- `loyalty_points` — rewards (feature flag)
- `recommendations` — ML recommendations (feature flag)
- `audit_log` — full change history
- `orders_archive` — archived cancelled orders

**Analytics schema:**
- `order_metrics` — daily aggregated metrics
- `recommendation_events` — click/purchase events

**Reporting schema:**
- `monthly_sales` — pre-aggregated monthly reports
- `v_daily_performance` — cross-schema view

**Views (public):**
- `v_order_summary`
- `v_product_catalog`
- `v_review_summary`
- `v_recommendation_performance` (analytics schema)

---

## 4-Week Course Summary

| Week | Focus | Key Commands Learned |
|------|-------|---------------------|
| 1 | Foundations | `update`, `status`, `validate`, `tag`, `rollback` |
| 2 | Change types | `addColumn`, `createIndex`, `loadData`, `<sql>`, `includeAll` |
| 3 | Rollbacks & CI/CD | `futureRollbackSQL`, `diff`, `generateChangeLog`, GitHub Actions |
| 4 | Production patterns | Preconditions, multi-schema, batch migrations, `CONCURRENTLY` |

---

## What to Learn Next

1. **Testcontainers** — run Liquibase against a real DB in integration tests
2. **Flyway** — Liquibase's main competitor (simpler, SQL-only, no XML/YAML)
3. **PostgreSQL advanced features** — partitioning, pg_partman for large tables
4. **Liquibase Hub** — cloud dashboard for tracking deployments across environments
5. **Database CI** — tools like SchemaHero (Kubernetes-native), Atlas, or Bytebase

---

## Key Takeaways

- Feature flags with `labels` let you deploy schema before the code — decouple releases
- Preconditions make changesets idempotent — safe for onboarding partially-migrated DBs
- The full deployment lifecycle: `validate` → `futureRollbackSQL` → `tag` → `update`
- Production rollback: `rollbackSQL` → human review → `rollback --tag`
- Multi-schema separates concerns: app / analytics / reporting each have clean boundaries
- Large migrations need 3 changesets: add nullable → batch backfill → NOT VALID + VALIDATE

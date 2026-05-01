# Week 2, Day 6 — Organizing Changelogs

## Hands-On Files
Open: `week2/changelogs/master.xml`
Open: `week2/changelogs/patches/` (directory)

---

## The Problem with One Big Changelog

If you put all changesets in one file, you get:
- 1000-line files that are hard to review
- Git merge conflicts on every PR
- No separation between concerns (schema vs data vs patches)

The solution: **split changelogs** and use `<include>` and `<includeAll>` to compose them.

---

## `<include>` — Explicit File Inclusion

```xml
<!-- master.xml -->
<databaseChangeLog ...>
    <include file="changelog/day1-table-column-ops.xml"/>
    <include file="changelog/day2-constraints-indexes.xml"/>
    <include file="changelog/day3-data-migrations.xml"/>
</databaseChangeLog>
```

- Files are included **in the order listed**
- If a file doesn't exist, Liquibase throws an error
- Use this when you want explicit control over ordering

---

## `<includeAll>` — Directory-Based Auto-Discovery

```xml
<includeAll path="changelog/patches/"/>
```

- Automatically discovers ALL changelog files in the directory
- Loaded in **alphabetical order** by filename
- New patch files dropped in the folder are auto-included on next `update`

This is powerful for:
- Hotfix patches that teams contribute independently
- Microservice database migrations managed by different teams
- Any scenario where you want "add file → automatically included"

---

## Alphabetical Ordering with `<includeAll>`

Because files are loaded alphabetically, naming matters:

```
patches/
  patch-001-add-discount.xml    ← runs first
  patch-002-add-coupon.xml      ← runs second
  patch-003-add-reviews.xml     ← runs third
```

**Bad naming:**
```
patches/
  add-coupon.xml      ← could sort before or after others unpredictably
  add-discount.xml
  fix-status.xml
```

**Good naming with dates:**
```
patches/
  2024-01-15-add-discount.xml
  2024-01-22-add-coupon.xml
  2024-02-03-fix-status.xml
```

**Good naming with sequential numbers:**
```
patches/
  patch-001-add-discount.xml
  patch-002-add-coupon.xml
```

---

## Recommended Project Structure

For a real-world project, this layout scales well:

```
changelogs/
├── master.xml                    ← entry point — includes everything
├── schema/                       ← structural changes (CREATE, ALTER)
│   ├── 001-create-users.xml
│   ├── 002-create-orders.xml
│   └── 003-create-products.xml
├── data/                         ← reference data (no context)
│   ├── 001-categories.xml
│   └── 002-statuses.xml
├── seed/                         ← dev/test data (context="dev")
│   ├── 001-test-users.xml
│   └── 002-test-orders.xml
└── patches/                      ← hotfixes, feature additions (includeAll)
    ├── 2024-01-15-add-discount.xml
    └── 2024-01-22-add-coupon.xml
```

master.xml ties it together:
```xml
<databaseChangeLog>
    <includeAll path="changelog/schema/"/>
    <includeAll path="changelog/data/"/>
    <includeAll path="changelog/seed/"/>
    <includeAll path="changelog/patches/"/>
</databaseChangeLog>
```

---

## `<include>` Options

```xml
<include
    file="changelog/day1.xml"
    relativeToChangelogFile="true"   <!-- path relative to this master.xml -->
    errorIfMissing="true"            <!-- default: throw error if file missing -->
/>
```

## `<includeAll>` Options

```xml
<includeAll
    path="changelog/patches/"
    relativeToChangelogFile="true"
    errorIfMissingOrEmpty="false"    <!-- don't error if folder is empty -->
    filter=".*\.xml"                 <!-- only include .xml files -->
/>
```

---

## Multi-Module / Multi-Service Structure

In a microservices setup where each service owns its DB schema:

```
services/
├── users-service/
│   └── changelogs/master.xml
├── orders-service/
│   └── changelogs/master.xml
└── products-service/
    └── changelogs/master.xml
```

Each service runs `liquibase update` independently, pointing to its own master.xml and its own database/schema.

---

## Verify the patches/ auto-discovery

```bash
# Apply week2 (includes patches/ via includeAll)
docker compose run --rm liquibase update

# See which files were included
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT DISTINCT filename FROM databasechangelog ORDER BY filename;"

# Verify the coupon table was created from patch-002
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d coupons"
```

---

## Key Takeaways

- `<include>` = explicit file, explicit order — for core changelog structure
- `<includeAll>` = entire directory, alphabetical order — for patches and auto-discovery
- Always prefix patch files with numbers or dates for predictable alphabetical ordering
- Separate concerns: `schema/` vs `data/` vs `seed/` vs `patches/`
- Each team/service should have its own master.xml and own database

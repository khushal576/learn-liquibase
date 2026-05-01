# Day 1 — Why Liquibase? The Problem It Solves

## The Problem Without Liquibase

Imagine a team of 3 developers working on the same app with a database.

**Developer A** adds a `users` table locally and runs:
```sql
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));
```

**Developer B** adds an `orders` table and runs:
```sql
CREATE TABLE orders (id SERIAL PRIMARY KEY, user_id INT);
```

Now they have questions with no good answers:
- How does Developer C know which SQL scripts to run and in what order?
- What if Developer A already ran script 1 but not script 2?
- How do you know what the **production** database looks like right now?
- If a deployment breaks, how do you roll back the DB change?
- Did the staging DB get the same changes as production?

This is called **schema drift** — your databases are in different states and nobody knows for sure.

---

## The Solution: Treat DB Changes Like Code

Liquibase solves this by giving your database the same workflow Git gives your code:

| Git (code) | Liquibase (database) |
|------------|----------------------|
| Commit | Changeset |
| Commit history | DATABASECHANGELOG table |
| `git pull` | `liquibase update` |
| `git revert` | `liquibase rollback` |
| `.git` folder | DATABASECHANGELOG table |

Every change is:
1. **Written** in a changelog file (not run manually)
2. **Committed to Git** alongside the code that needs it
3. **Applied by Liquibase** — which tracks what's already been run
4. **Never applied twice** — Liquibase checks before every run

---

## Real-World Pain Points Liquibase Fixes

| Pain | How Liquibase Fixes It |
|------|----------------------|
| "Did prod get that index?" | DATABASECHANGELOG tells you exactly |
| Manual SQL scripts run out of order | Changelogs have a defined order |
| Schema differences between dev/staging/prod | Same changelog file runs everywhere |
| "How do I undo this migration?" | Rollback blocks in every changeset |
| Concurrent deployments overwriting each other | DATABASECHANGELOGLOCK prevents this |

---

## Key Terms to Know

- **Changelog** — the file (XML/YAML/SQL/JSON) that contains your changes
- **Changeset** — one unit of change inside a changelog (like a single commit)
- **DATABASECHANGELOG** — a table Liquibase creates in your DB to track what's been run
- **DATABASECHANGELOGLOCK** — a table Liquibase uses to prevent two processes running at the same time

---

## Today's Exercise

Think about a project you've worked on. Write down 3 database changes that were painful to coordinate across environments. These are exactly the scenarios Liquibase solves.

# Week 3, Day 7 — Spring Boot + Liquibase Integration

## Hands-On File
Open: `week3/changelogs/day7-springboot-schema.xml`

---

## How Spring Boot Integrates Liquibase

Spring Boot has **first-class Liquibase support**. Add the dependency and a changelog file, and Liquibase runs automatically at startup — before your application accepts traffic.

### Dependency (Maven)
```xml
<dependency>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-core</artifactId>
    <!-- version managed by Spring Boot BOM -->
</dependency>
```

### Dependency (Gradle)
```groovy
implementation 'org.liquibase:liquibase-core'
```

---

## Spring Boot Auto-Configuration

With `liquibase-core` on the classpath, Spring Boot:
1. Detects your `DataSource` bean
2. Creates a `SpringLiquibase` bean
3. Calls `liquibase.update()` during application startup
4. Application startup fails if migration fails (preventing broken deployments)

Default changelog location: `classpath:db/changelog/db.changelog-master.xml`

---

## Project Layout for Spring Boot

```
src/
└── main/
    ├── java/com/example/app/
    └── resources/
        ├── application.yml
        └── db/
            └── changelog/
                ├── db.changelog-master.xml    ← Spring Boot looks here by default
                ├── changes/
                │   ├── 001-create-users.xml
                │   ├── 002-create-orders.xml
                │   └── 003-add-sessions.xml
                └── data/
                    └── 001-reference-data.xml
```

---

## application.yml Configuration

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/learndb
    username: ${DB_USER}
    password: ${DB_PASSWORD}
    driver-class-name: org.postgresql.Driver

  liquibase:
    # Default: classpath:db/changelog/db.changelog-master.xml
    change-log: classpath:db/changelog/db.changelog-master.xml

    # Run migrations on startup (default: true)
    enabled: true

    # Context to activate (maps to Liquibase --contexts)
    contexts: ${SPRING_PROFILES_ACTIVE:dev}

    # Label filter (maps to --labels)
    label-filter: ""

    # Schema where DATABASECHANGELOG lives
    default-schema: public
    liquibase-schema: public

    # Drop and recreate the whole DB (NEVER use in production)
    drop-first: false

    # Tag the DB state after update
    tag: ""

    # Test rollback and re-apply (good for dev, expensive for prod)
    test-rollback-on-update: false
```

---

## Per-Environment Configuration

```yaml
# application-dev.yml
spring:
  liquibase:
    contexts: dev
    drop-first: false

# application-test.yml
spring:
  liquibase:
    contexts: test
    drop-first: true          # clean DB on every test run

# application-prod.yml
spring:
  liquibase:
    contexts: prod
    test-rollback-on-update: false
```

---

## `test-rollback-on-update: true` in Development

When enabled, Spring Boot:
1. Runs `liquibase update` (applies all pending changes)
2. Immediately runs `liquibase rollback` to undo them
3. Then runs `liquibase update` again to re-apply

This verifies your rollback scripts are valid on every startup in dev. It's expensive (2x migrations) but catches broken rollbacks immediately.

---

## Disabling Liquibase for Tests

For unit tests that mock the database, disable Liquibase:

```java
@SpringBootTest
@TestPropertySource(properties = "spring.liquibase.enabled=false")
class UserServiceTest {
    @MockBean
    DataSource dataSource;
    // ...
}
```

For integration tests, keep it enabled and let it run:
```java
@SpringBootTest
@Testcontainers
class UserRepositoryTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        // Liquibase runs automatically against the Testcontainer
    }
}
```

---

## The `db.changelog-master.xml` for Spring Boot

```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.27.xsd">

    <!-- Schema changes (no context — runs everywhere) -->
    <includeAll path="classpath:db/changelog/changes/"/>

    <!-- Reference data (no context — required everywhere) -->
    <includeAll path="classpath:db/changelog/data/"/>

</databaseChangeLog>
```

---

## Logging Liquibase Output

```yaml
logging:
  level:
    liquibase: INFO          # Show which changesets are applied
    # liquibase: DEBUG       # Show full SQL (useful for debugging)
```

---

## Hands-On Exercise

```bash
# Run week3 changelogs (which includes day7-springboot-schema.xml)
docker compose run --rm liquibase \
  --url=jdbc:postgresql://postgres:5432/learndb \
  --username=liquibase --password=liquibase123 \
  --changeLogFile=week3/changelogs/master.xml \
  update

# Verify user_sessions table was created
docker exec -it liquibase_db psql -U liquibase -d learndb -c "\d user_sessions"

# Verify job_executions only appears with prod context
docker exec -it liquibase_db psql -U liquibase -d learndb \
  -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"
```

---

## Week 3 Summary

| Day | Topic | Key Commands |
|-----|-------|-------------|
| 1 | Rollback strategies | `rollback --tag`, `rollbackCount`, `rollbackToDate` |
| 2 | Complex rollback blocks | `futureRollbackSQL`, multi-step, data-loss patterns |
| 3 | Preview commands | `updateSQL`, `rollbackSQL`, `rollbackCountSQL`, `status`, `history` |
| 4 | Diff and reverse-engineer | `diff`, `diffChangeLog`, `generateChangeLog`, `changeLogSync` |
| 5 | CI/CD integration | GitHub Actions, GitLab CI, Docker runner, approval gates |
| 6 | Pipeline deep dive | Artifacts, secrets, per-environment config, manual rollback |
| 7 | Spring Boot | Auto-config, `application.yml`, Testcontainers, `test-rollback-on-update` |

You're ready for Week 4 — advanced patterns, preconditions, multi-schema, and production practices.

---

## Key Takeaways

- Spring Boot runs Liquibase automatically at startup — no code needed
- Failed migration = failed startup = deployment blocked (this is the feature, not a bug)
- Use `spring.liquibase.contexts` to map to Spring profiles
- `test-rollback-on-update: true` in dev catches broken rollbacks immediately
- Disable Liquibase for unit tests, keep it enabled for integration tests
- Use Testcontainers for integration tests — real Postgres, ephemeral, no cleanup needed

# Week 4, Day 4 — Maven and Gradle Plugins

## No New Changelog Today
Day 4 covers build tool integration. The changelogs are the same — you're just using a different way to run Liquibase.

---

## Why Use a Build Plugin Instead of the CLI?

| CLI | Maven/Gradle Plugin |
|-----|---------------------|
| Separate install | Bundled with build — no install needed |
| Manual credential management | Reads from build config / environment |
| Separate step in CI | Integrated with build lifecycle |
| Good for standalone ops | Good for Java projects |

For Java projects (Spring Boot, etc.), the plugin integrates Liquibase into your normal build and test workflow. For ops teams, the CLI or Docker image is usually simpler.

---

## Maven Plugin

### Add to `pom.xml`
```xml
<plugin>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-maven-plugin</artifactId>
    <version>4.27.0</version>
    <configuration>
        <changeLogFile>src/main/resources/db/changelog/master.xml</changeLogFile>
        <driver>org.postgresql.Driver</driver>
        <url>${db.url}</url>
        <username>${db.username}</username>
        <password>${db.password}</password>
        <promptOnNonLocalDatabase>false</promptOnNonLocalDatabase>
        <contexts>${liquibase.contexts}</contexts>
    </configuration>
    <dependencies>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <version>42.7.1</version>
        </dependency>
    </dependencies>
</plugin>
```

### Maven Commands
```bash
# Apply migrations
mvn liquibase:update

# Check pending
mvn liquibase:status

# Validate
mvn liquibase:validate

# Preview SQL
mvn liquibase:updateSQL

# Rollback to tag
mvn liquibase:rollback -Dliquibase.rollbackTag=v1.0.0

# Rollback last N
mvn liquibase:rollbackCount -Dliquibase.rollbackCount=2

# Generate changelog from existing DB
mvn liquibase:generateChangeLog

# Diff two databases
mvn liquibase:diff
```

### Maven Profiles for Environments
```xml
<profiles>
    <profile>
        <id>dev</id>
        <properties>
            <db.url>jdbc:postgresql://localhost:5432/learndb_dev</db.url>
            <db.username>dev_user</db.username>
            <db.password>dev_pass</db.password>
            <liquibase.contexts>dev</liquibase.contexts>
        </properties>
    </profile>
    <profile>
        <id>prod</id>
        <properties>
            <db.url>${env.DB_URL}</db.url>
            <db.username>${env.DB_USER}</db.username>
            <db.password>${env.DB_PASSWORD}</db.password>
            <liquibase.contexts>prod</liquibase.contexts>
        </properties>
    </profile>
</profiles>
```

Run with profile:
```bash
mvn liquibase:update -Pdev
mvn liquibase:update -Pprod
```

---

## Gradle Plugin

### Add to `build.gradle`
```groovy
plugins {
    id 'org.liquibase.gradle' version '2.2.0'
}

dependencies {
    liquibaseRuntime 'org.liquibase:liquibase-core:4.27.0'
    liquibaseRuntime 'org.postgresql:postgresql:42.7.1'
}

liquibase {
    activities {
        main {
            changeLogFile 'src/main/resources/db/changelog/master.xml'
            url           System.getenv('DB_URL')     ?: 'jdbc:postgresql://localhost:5432/learndb'
            username      System.getenv('DB_USER')    ?: 'liquibase'
            password      System.getenv('DB_PASSWORD') ?: 'liquibase123'
            contexts      System.getenv('CONTEXTS')   ?: 'dev'
        }
    }
    runList = 'main'
}
```

### Gradle Commands
```bash
# Apply migrations
./gradlew update

# Check pending
./gradlew status

# Validate
./gradlew validate

# Preview SQL
./gradlew updateSQL

# Rollback to tag
./gradlew rollback -PliquibaseCommandValue=v1.0.0

# Generate changelog
./gradlew generateChangelog
```

### Multiple Environments in Gradle
```groovy
liquibase {
    activities {
        dev {
            changeLogFile 'src/main/resources/db/changelog/master.xml'
            url      'jdbc:postgresql://localhost:5432/learndb_dev'
            username 'dev_user'
            password 'dev_pass'
            contexts 'dev'
        }
        prod {
            changeLogFile 'src/main/resources/db/changelog/master.xml'
            url      System.getenv('PROD_DB_URL')
            username System.getenv('PROD_DB_USER')
            password System.getenv('PROD_DB_PASSWORD')
            contexts 'prod'
        }
    }
    runList = project.ext.runEnv ?: 'dev'
}
```

Run with:
```bash
./gradlew update -PrunEnv=prod
```

---

## Integrating with Test Lifecycle

### Maven — run migrations before integration tests
```xml
<plugin>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-maven-plugin</artifactId>
    <executions>
        <execution>
            <id>migrate-for-tests</id>
            <phase>pre-integration-test</phase>
            <goals>
                <goal>update</goal>
            </goals>
            <configuration>
                <url>jdbc:postgresql://localhost:5432/learndb_test</url>
                <contexts>test</contexts>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Gradle — run migrations before tests
```groovy
test {
    dependsOn 'update'
}
```

---

## Key Takeaways

- Maven plugin: use `mvn liquibase:<command>` — config in `pom.xml`
- Gradle plugin: use `./gradlew <command>` — config in `build.gradle`
- Use Maven profiles or Gradle `runList` for per-environment config
- Never hardcode credentials — read from `System.getenv()` or CI variables
- Bind to build lifecycle phases (`pre-integration-test`) for automatic test DB setup
- For non-Java projects, the CLI or Docker image is simpler than a build plugin

# =============================================================================
# Stage 1: Builder - Maven + Eclipse Temurin JDK 11
# =============================================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy the entire project structure for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -q || true

# Copy source code
COPY src ./src

# Build the WAR (cloud profile with PostgreSQL support)
RUN mvn clean package -Pcloud -DskipTests \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/postgres" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"

# =============================================================================
# Stage 2: Runtime - Payara Server Full (explicit base image)
# =============================================================================
FROM payara/server-full:6.2023.12

# Copy the post-boot admin commands
COPY post-boot-commands.asadmin /opt/payara/config/

# Copy the PostgreSQL JDBC driver and WAR from builder
COPY --from=builder /workspace/target/postgresql.jar /tmp/postgresql.jar
COPY --from=builder /workspace/target/cargo-tracker.war /tmp/cargo-tracker.war

# Expose Payara HTTP port
EXPOSE 8080

# Payara admin port (optional, for management)
EXPOSE 4848

# Environment variables for runtime configuration
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    TZ=UTC \
    PAYARA_ARGS=""

# The default CMD from payara/server-full starts the domain with post-boot commands
# No HEALTHCHECK instruction - ECS service/ALB handles health checking

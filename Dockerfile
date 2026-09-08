# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy full source code
COPY src ./src

# Build the WAR (cloud profile with PostgreSQL support)
RUN mvn clean package -Pcloud -DskipTests \
    -DpostgreSqlJdbcUrl="${DB_JDBC_URL:-jdbc:postgresql://localhost:5432/cargotracker}" \
    -DpostgreSqlUsername="${DB_USER:-postgres}" \
    -DpostgreSqlPassword="${DB_PASSWORD:-postgres}"

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker" \
      application="cargo-tracker" \
      version="3.1"

# Set environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"

# Create non-root user
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Install Payara Micro
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} && \
    curl -fsSL "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -o ${PAYARA_HOME}/payara-micro.jar && \
    chown -R payara:payara ${PAYARA_HOME}

WORKDIR ${PAYARA_HOME}

# Copy WAR and PostgreSQL driver from builder
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder /workspace/target/postgresql.jar ${PAYARA_HOME}/postgresql.jar

# Copy post-boot commands
COPY post-boot-commands.asadmin ${PAYARA_HOME}/post-boot-commands.asadmin

# Expose application port
EXPOSE 8080

# Switch to non-root user
USER payara

# Start Payara Micro
ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} -jar ${PAYARA_HOME}/payara-micro.jar \
    --deploy ${DEPLOY_DIR}/cargo-tracker.war \
    --addLibs ${PAYARA_HOME}/postgresql.jar \
    --port 8080 \
    --noCluster"]

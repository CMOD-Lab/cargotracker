# ============================================================
# Multi-stage Dockerfile for Eclipse Cargo Tracker
# Build Tool : Maven (system mvn - no wrapper)
# Java Version: 11
# Package Type: WAR (Jakarta EE / Payara Micro)
# Runtime     : amazoncorretto:11 (explicit base image)
# Target      : Azure AKS
# ============================================================

# ---- Stage 1: Build ----
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy dependency descriptors first for layer caching
COPY pom.xml .

# Download all dependencies (offline-friendly layer)
RUN mvn dependency:go-offline -B -q

# Copy the full project source (no wrapper files - excluded via .dockerignore)
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (skip tests in Docker build)
RUN mvn clean package -DskipTests -B -q

# ---- Stage 2: Runtime ----
FROM amazoncorretto:11

# Metadata labels
LABEL maintainer="Eclipse Cargo Tracker Team" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT" \
      description="Eclipse Cargo Tracker - Jakarta EE DDD Reference Application"

# Environment variables
ENV TZ=UTC \
    LANG=en_US.UTF-8 \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    DB_JDBC_URL=jdbc:h2:file:./cargo-tracker-data/cargo-tracker-database \
    DB_DRIVER_CLASS=org.h2.jdbcx.JdbcDataSource \
    DB_USER="" \
    DB_PASSWORD="" \
    GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path \
    SEND_ERROR_IN_RESPONSE=true

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Install Payara Micro
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} /opt/payara/config && \
    curl -fsSL "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -o ${PAYARA_HOME}/payara-micro.jar && \
    chown -R payara:payara ${PAYARA_HOME}

# Copy the built WAR from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder /workspace/post-boot-commands.asadmin ${PAYARA_HOME}/config/post-boot-commands.asadmin

# Fix ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} -jar ${PAYARA_HOME}/payara-micro.jar \
   --deploy ${DEPLOY_DIR}/cargo-tracker.war \
   --port 8080 \
   --noCluster"]

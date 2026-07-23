# ============================================================
# Stage 1: Builder
# Eclipse Cargo Tracker - Jakarta EE 10 / Payara Micro WAR
# Java 11, Maven build
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy entire project (single-module Maven project)
# Copy pom.xml first to leverage Docker layer caching for dependencies
COPY pom.xml .

# Download all dependencies offline (cache layer)
RUN mvn dependency:go-offline -DskipTests -q || true

# Copy source code
COPY src ./src

# Build the WAR using the payara profile (default active profile)
RUN mvn clean package -DskipTests -Ppayara

# ============================================================
# Stage 2: Runtime
# Use explicit base image: eclipse-temurin:11-jdk
# Payara Micro is embedded as a runnable JAR
# ============================================================
FROM eclipse-temurin:11-jdk

# Metadata labels
LABEL maintainer="cargo-tracker-team" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT" \
      description="Eclipse Cargo Tracker - Jakarta EE 10 DDD Reference Application"

# Set environment variables
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    PAYARA_VERSION=6.2025.3 \
    APP_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${APP_HOME} -s /bin/bash payara

# Create application directories
RUN mkdir -p ${APP_HOME} ${DEPLOY_DIR} /opt/payara/data && \
    chown -R payara:payara ${APP_HOME}

# Download Payara Micro
RUN apt-get update && apt-get install -y --no-install-recommends wget && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -O ${APP_HOME}/payara-micro.jar && \
    apt-get remove -y wget && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    chown payara:payara ${APP_HOME}/payara-micro.jar

# Copy the built WAR from builder stage
COPY --from=builder --chown=payara:payara /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Copy post-boot commands for Payara Micro configuration
COPY --chown=payara:payara post-boot-commands.asadmin ${APP_HOME}/post-boot-commands.asadmin

# Switch to non-root user
USER payara

WORKDIR ${APP_HOME}

# Expose application port
EXPOSE 8080

# Expose admin port (optional, for management)
EXPOSE 4848

# Use exec form for proper signal handling (graceful shutdown)
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar ${APP_HOME}/payara-micro.jar \
  --deploy ${DEPLOY_DIR}/cargo-tracker.war \
  --postbootcommandfile ${APP_HOME}/post-boot-commands.asadmin \
  --contextroot / \
  --port 8080"]

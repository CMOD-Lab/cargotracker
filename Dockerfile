# ============================================================
# Multi-stage Dockerfile for Eclipse Cargo Tracker
# Jakarta EE 10 Web Application (WAR) on Payara Server
# Java 11 | Maven | Azure AKS Deployment
# ============================================================

# ---- Stage 1: Build ----
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -Ppayara -q

# Copy full source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (payara profile, skip tests)
RUN mvn clean package -Ppayara -DskipTests

# ---- Stage 2: Runtime ----
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT" \
      description="Eclipse Cargo Tracker - Jakarta EE 10 DDD Reference Application"

# Environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/glassfish/domains/domain1/autodeploy \
    TZ=UTC \
    JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions -Xms256m -Xmx512m -Dfile.encoding=UTF-8 -Duser.timezone=UTC"

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Install Payara Server
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip && \
    mkdir -p ${PAYARA_HOME} && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip" \
         -O /tmp/payara.zip && \
    unzip -q /tmp/payara.zip -d /opt && \
    mv /opt/payara6 ${PAYARA_HOME} || true && \
    rm -f /tmp/payara.zip && \
    apt-get remove -y wget unzip && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    chown -R payara:payara ${PAYARA_HOME}

# Copy built WAR and post-boot commands
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder /workspace/post-boot-commands.asadmin ${PAYARA_HOME}/config/post-boot-commands.asadmin

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

# Expose application port and admin port
EXPOSE 8080 4848

# Start Payara with post-boot commands
CMD ["sh", "-c", "${PAYARA_HOME}/bin/asadmin start-domain --verbose domain1 & sleep 30 && ${PAYARA_HOME}/bin/asadmin --port 4848 multimode --file ${PAYARA_HOME}/config/post-boot-commands.asadmin && wait"]

# ============================================================
# Stage 1: Builder
# Eclipse Cargo Tracker - Jakarta EE 10 WAR application
# Build tool: Maven | Java 11 | Packaging: WAR
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency layer caching
COPY pom.xml .

# Download dependencies (cached layer unless pom.xml changes)
RUN mvn dependency:go-offline -B -P payara

# Copy full source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR artifact (Payara profile, skip tests)
RUN mvn clean package -DskipTests -B -P payara

# ============================================================
# Stage 2: Runtime
# Explicit base image: amazoncorretto:11
# Runtime: Payara Micro (self-contained JAR launcher)
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT" \
      description="Eclipse Cargo Tracker - Jakarta EE 10 DDD Reference Application"

# Environment variables
ENV TZ=UTC \
    LANG=en_US.UTF-8 \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    PAYARA_VERSION=6.2025.3 \
    DEPLOY_DIR=/opt/payara/deployments \
    CONFIG_DIR=/opt/payara/config \
    DATA_DIR=/opt/payara/data

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d /opt/payara -s /sbin/nologin payara

# Create required directories
RUN mkdir -p ${DEPLOY_DIR} ${CONFIG_DIR} ${DATA_DIR}/cargo-tracker-data && \
    chown -R payara:payara /opt/payara

# Download Payara Micro
RUN curl -fsSL \
    "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
    -o /opt/payara/payara-micro.jar && \
    chown payara:payara /opt/payara/payara-micro.jar

# Copy built WAR from builder stage
COPY --from=builder --chown=payara:payara /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Copy post-boot admin commands
COPY --from=builder --chown=payara:payara /workspace/post-boot-commands.asadmin ${CONFIG_DIR}/post-boot-commands.asadmin

# Switch to non-root user
USER payara

WORKDIR /opt/payara

# Expose application port
EXPOSE 8080

# Expose management/HTTPS port
EXPOSE 8081

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
    "java ${JAVA_OPTS} \
     -jar /opt/payara/payara-micro.jar \
     --deploy ${DEPLOY_DIR}/cargo-tracker.war \
     --contextroot / \
     --port 8080 \
     --sslport 8081 \
     --noCluster \
     --logToFile /opt/payara/data/payara.log"]

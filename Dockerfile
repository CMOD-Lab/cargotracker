# ============================================================
# Stage 1: Build Stage
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy Maven build descriptor first for dependency caching
COPY pom.xml .

# Download dependencies (leverages Docker layer cache)
RUN mvn dependency:go-offline -B

# Copy the full project source
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (cloud profile with PostgreSQL support)
RUN mvn clean package -Pcloud -DskipTests -B

# ============================================================
# Stage 2: Runtime Stage
# ============================================================
FROM eclipse-temurin:11-jdk

LABEL maintainer="Eclipse Cargo Tracker"
LABEL description="Eclipse Cargo Tracker - Jakarta EE Application on Payara Micro"
LABEL version="3.1-SNAPSHOT"

# Set environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Create required directories
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} /opt/payara/config /opt/cargo-tracker-data \
    && chown -R payara:payara ${PAYARA_HOME} /opt/cargo-tracker-data

# Download Payara Micro
RUN apt-get update && apt-get install -y --no-install-recommends wget \
    && wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
       -O ${PAYARA_HOME}/payara-micro.jar \
    && apt-get remove -y wget && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Copy the built WAR and PostgreSQL driver from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder /workspace/target/postgresql.jar ${PAYARA_HOME}/postgresql.jar

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME} ${DEPLOY_DIR}

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} \
   -jar ${PAYARA_HOME}/payara-micro.jar \
   --addLibs ${PAYARA_HOME}/postgresql.jar \
   --deploy ${DEPLOY_DIR}/cargo-tracker.war \
   --port 8080 \
   --contextroot /"]

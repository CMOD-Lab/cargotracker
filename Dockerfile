# ============================================================
# Stage 1: Build Stage
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy Maven build descriptor first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -Ppayara -DskipTests --batch-mode

# Copy the full source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR artifact using the cloud profile (PostgreSQL-ready)
RUN mvn clean package -Pcloud -DskipTests --batch-mode \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/cargotracker" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"

# ============================================================
# Stage 2: Runtime Stage
# ============================================================
FROM mcr.microsoft.com/openjdk/jdk:11-ubuntu

LABEL maintainer="Eclipse Cargo Tracker" \
      description="Eclipse Cargo Tracker - Jakarta EE Application on Payara Micro" \
      version="3.1-SNAPSHOT"

# Set environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    POSTGRES_HOST=localhost \
    POSTGRES_PORT=5432 \
    POSTGRES_DB=cargotracker \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Create required directories
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} /opt/payara/config /opt/payara/data

# Download Payara Micro
RUN apt-get update && apt-get install -y --no-install-recommends wget \
    && wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
       -O ${PAYARA_HOME}/payara-micro.jar \
    && apt-get remove -y wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Copy the built WAR and PostgreSQL driver from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder /workspace/target/postgresql.jar ${PAYARA_HOME}/postgresql.jar
COPY --from=builder /workspace/post-boot-commands.asadmin ${PAYARA_HOME}/config/post-boot-commands.asadmin

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080
EXPOSE 8081

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
    "java ${JAVA_OPTS} \
     -jar ${PAYARA_HOME}/payara-micro.jar \
     --addLibs ${PAYARA_HOME}/postgresql.jar \
     --postbootcommandfile ${PAYARA_HOME}/config/post-boot-commands.asadmin \
     --deploy ${DEPLOY_DIR}/cargo-tracker.war \
     --port 8080 \
     --sslport 8081 \
     --nocluster \
     --contextroot /cargo-tracker \
     --systemproperties \
     postgreSqlJdbcUrl=jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB} \
     postgreSqlUsername=${POSTGRES_USER} \
     postgreSqlPassword=${POSTGRES_PASSWORD}"]

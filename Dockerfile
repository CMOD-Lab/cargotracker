# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -Ppayara

# Copy full source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (using payara profile with H2 embedded DB)
RUN mvn clean package -DskipTests -Ppayara

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM eclipse-temurin:11-jdk

LABEL maintainer="Eclipse Cargo Tracker"
LABEL application="cargo-tracker"
LABEL version="3.1-SNAPSHOT"

# Install Payara Micro
ARG PAYARA_VERSION=6.2025.3
ENV PAYARA_VERSION=${PAYARA_VERSION}

RUN mkdir -p /opt/payara

# Download Payara Micro
ADD https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar /opt/payara/payara-micro.jar

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d /opt/payara -s /bin/bash payara \
    && chown -R payara:payara /opt/payara

# Create data directory for H2 database
RUN mkdir -p /opt/payara/cargo-tracker-data \
    && chown -R payara:payara /opt/payara/cargo-tracker-data

WORKDIR /opt/payara

# Copy the built WAR from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war /opt/payara/cargo-tracker.war
COPY --from=builder /workspace/post-boot-commands.asadmin /opt/payara/post-boot-commands.asadmin

# Set ownership
RUN chown -R payara:payara /opt/payara

USER payara

# Application port
EXPOSE 8080

# Environment variables
ENV TZ=UTC
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"
ENV GRAPH_TRAVERSAL_URL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"

# Run Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /opt/payara/payara-micro.jar \
    --deploy /opt/payara/cargo-tracker.war \
    --contextroot / \
    --port 8080 \
    --postbootcommandfile /opt/payara/post-boot-commands.asadmin"]

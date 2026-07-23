# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cached layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy the full source code
COPY src ./src

# Build the WAR (using cloud profile for PostgreSQL support)
RUN mvn clean package -Pcloud -DskipTests

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM mcr.microsoft.com/openjdk/jdk:11-ubuntu

LABEL maintainer="Eclipse Cargo Tracker" \
      app="cargo-tracker" \
      version="3.1-SNAPSHOT"

# Install Payara Micro
ENV PAYARA_VERSION=6.2025.3
ENV PAYARA_HOME=/opt/payara

RUN mkdir -p ${PAYARA_HOME} && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download Payara Micro
ADD https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar \
    ${PAYARA_HOME}/payara-micro.jar

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /sbin/nologin payara && \
    chown -R payara:payara ${PAYARA_HOME}

WORKDIR ${PAYARA_HOME}

# Copy the built WAR from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${PAYARA_HOME}/cargo-tracker.war

# Copy PostgreSQL driver from builder stage (cloud profile)
COPY --from=builder /workspace/target/postgresql.jar ${PAYARA_HOME}/postgresql.jar

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

# Application port
EXPOSE 8080
EXPOSE 8081

# Environment variables
ENV TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    DB_DRIVER_CLASS=org.postgresql.ds.PGPoolingDataSource \
    DB_JDBC_URL=jdbc:postgresql://localhost:5432/cargotracker \
    DB_USER=postgres \
    DB_PASSWORD=postgres \
    GRAPH_TRAVERSAL_URL=http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path

# Start Payara Micro with the WAR
ENTRYPOINT ["sh", "-c", \
    "java ${JAVA_OPTS} -jar ${PAYARA_HOME}/payara-micro.jar \
    --addLibs ${PAYARA_HOME}/postgresql.jar \
    --deploy ${PAYARA_HOME}/cargo-tracker.war \
    --port 8080 \
    --sslPort 8081 \
    --systemproperties db.driverClass=${DB_DRIVER_CLASS} \
    --systemproperties db.jdbcUrl=${DB_JDBC_URL} \
    --systemproperties db.user=${DB_USER} \
    --systemproperties db.password=${DB_PASSWORD} \
    --systemproperties webapp.graphTraversalUrl=${GRAPH_TRAVERSAL_URL}"]

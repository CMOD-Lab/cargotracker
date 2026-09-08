# ============================================================
# Stage 1: Builder
# Eclipse Cargo Tracker - Jakarta EE WAR application
# Build tool: Maven | Java 11 | WAR packaging
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency layer caching
COPY pom.xml .

# Download dependencies (cached layer unless pom.xml changes)
RUN mvn dependency:go-offline -Pcloud -q

# Copy full source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR and download PostgreSQL JDBC driver (cloud profile)
RUN mvn clean package -Pcloud -DskipTests \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/postgres" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"

# ============================================================
# Stage 2: Runtime
# Using explicit base image: amazoncorretto:11
# Payara Micro embedded runtime for Jakarta EE WAR deployment
# ============================================================
FROM amazoncorretto:11

# Metadata labels
LABEL maintainer="cargo-tracker-team" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT" \
      description="Eclipse Cargo Tracker - Jakarta EE Application"

# Environment variables
ENV TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    PAYARA_VERSION=6.2025.3 \
    DEPLOY_DIR=/opt/payara/deployments \
    CONFIG_DIR=/opt/payara/config \
    DB_HOST=localhost \
    DB_PORT=5432 \
    DB_NAME=postgres \
    DB_USER=postgres \
    DB_PASSWORD=postgres \
    GRAPH_TRAVERSAL_URL=http://localhost:8080/rest/graph-traversal/shortest-path

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d /opt/payara -s /bin/bash payara

# Create required directories
RUN mkdir -p ${DEPLOY_DIR} ${CONFIG_DIR} /opt/payara/lib && \
    chown -R payara:payara /opt/payara

# Download Payara Micro JAR
RUN yum install -y wget && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -O /opt/payara/payara-micro.jar && \
    yum remove -y wget && \
    yum clean all && \
    chown payara:payara /opt/payara/payara-micro.jar

# Copy WAR artifact and PostgreSQL JDBC driver from builder
COPY --from=builder --chown=payara:payara /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder --chown=payara:payara /workspace/target/postgresql.jar /opt/payara/lib/postgresql.jar
COPY --from=builder --chown=payara:payara /workspace/post-boot-commands.asadmin ${CONFIG_DIR}/post-boot-commands.asadmin

# Switch to non-root user
USER payara

WORKDIR /opt/payara

# Expose application port
EXPOSE 8080

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} \
    -jar /opt/payara/payara-micro.jar \
    --addLibs /opt/payara/lib/postgresql.jar \
    --postbootcommandfile ${CONFIG_DIR}/post-boot-commands.asadmin \
    --deploy ${DEPLOY_DIR}/cargo-tracker.war \
    --port 8080 \
    --nocluster"]

# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy Maven build descriptor first for dependency caching
COPY pom.xml .

# Download all dependencies (layer cache optimization)
RUN mvn dependency:go-offline -B -Pcloud

# Copy the full project source
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (cloud profile includes PostgreSQL JDBC driver)
RUN mvn clean package -DskipTests -Pcloud \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/postgres" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT"

# Environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    ADMIN_USER=admin \
    ADMIN_PASSWORD=admin \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions -Dfile.encoding=UTF-8 -Duser.timezone=UTC"

# Install Payara Micro
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} && \
    yum install -y wget && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -O "${PAYARA_HOME}/payara-micro.jar" && \
    yum remove -y wget && \
    yum clean all && \
    rm -rf /var/cache/yum

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /sbin/nologin payara && \
    chown -R payara:payara ${PAYARA_HOME}

# Copy application artifacts from builder stage
COPY --from=builder --chown=payara:payara /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder --chown=payara:payara /workspace/target/postgresql.jar ${PAYARA_HOME}/postgresql.jar

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080
EXPOSE 8081

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} -jar ${PAYARA_HOME}/payara-micro.jar \
   --addLibs ${PAYARA_HOME}/postgresql.jar \
   --deploy ${DEPLOY_DIR}/cargo-tracker.war \
   --port 8080 \
   --sslPort 8081 \
   --noCluster"]

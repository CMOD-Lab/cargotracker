# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy dependency descriptors first for layer caching
COPY pom.xml .

# Download dependencies (offline cache layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy full project source
COPY src ./src

# Build the WAR (Payara profile is active by default)
RUN mvn clean package -DskipTests -Ppayara

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker" \
      description="Eclipse Cargo Tracker - Jakarta EE 10 application on Payara Micro" \
      version="3.1-SNAPSHOT"

# Environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions -Dfile.encoding=UTF-8 -Duser.timezone=UTC"

# Create non-root user
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Create required directories
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} /opt/payara/cargo-tracker-data && \
    chown -R payara:payara ${PAYARA_HOME}

# Download Payara Micro
RUN yum install -y wget && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -O ${PAYARA_HOME}/payara-micro.jar && \
    yum remove -y wget && \
    yum clean all && \
    chown payara:payara ${PAYARA_HOME}/payara-micro.jar

# Copy the built WAR from builder stage
COPY --from=builder --chown=payara:payara /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080

# Start Payara Micro with the deployed WAR
ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} -jar ${PAYARA_HOME}/payara-micro.jar \
   --deploy ${DEPLOY_DIR}/cargo-tracker.war \
   --contextroot / \
   --port 8080 \
   --nocluster"]

# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy full source code
COPY src ./src

# Build the WAR (using cloud profile for production build)
RUN mvn clean package -DskipTests -q

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker" \
      application="cargo-tracker" \
      version="3.1-SNAPSHOT"

# Set environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/deployments \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"

# Install Payara Micro
RUN mkdir -p ${PAYARA_HOME} && \
    mkdir -p ${DEPLOY_DIR}

# Download Payara Micro
RUN yum install -y wget && \
    wget -q https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar \
         -O ${PAYARA_HOME}/payara-micro.jar && \
    yum remove -y wget && \
    yum clean all

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} payara && \
    chown -R payara:payara ${PAYARA_HOME}

# Copy WAR artifact from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080

# Start Payara Micro with the WAR
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar ${PAYARA_HOME}/payara-micro.jar \
    --deploy ${DEPLOY_DIR}/cargo-tracker.war \
    --port 8080 \
    --contextroot /"]

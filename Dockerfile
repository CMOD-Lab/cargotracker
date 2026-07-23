# =============================================================================
# Stage 1: Builder
# =============================================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy entire project structure for build
COPY . .

# Build the application (skip tests for Docker build)
RUN mvn clean package -DskipTests -Ppayara

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker"
LABEL application="cargo-tracker"
LABEL version="3.1-SNAPSHOT"

# Set environment variables
ENV PAYARA_VERSION=6.2025.3
ENV PAYARA_HOME=/opt/payara
ENV DEPLOY_DIR=${PAYARA_HOME}/glassfish/domains/domain1/autodeploy
ENV TZ=UTC
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions -Djava.net.preferIPv4Stack=true"

# Install required tools
RUN yum update -y && \
    yum install -y unzip wget && \
    yum clean all

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Download and install Payara Server
RUN mkdir -p ${PAYARA_HOME} && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip" \
         -O /tmp/payara.zip && \
    unzip -q /tmp/payara.zip -d /opt && \
    mv /opt/payara6 ${PAYARA_HOME} && \
    rm -f /tmp/payara.zip && \
    chown -R payara:payara ${PAYARA_HOME}

# Copy the built WAR artifact from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Copy post-boot admin commands
COPY --from=builder /workspace/post-boot-commands.asadmin ${PAYARA_HOME}/config/post-boot-commands.asadmin

# Set proper ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

# Expose application port
EXPOSE 8080
EXPOSE 4848

# Set working directory
WORKDIR ${PAYARA_HOME}

# Start Payara Server
ENTRYPOINT ["sh", "-c", "${PAYARA_HOME}/bin/asadmin start-domain --verbose domain1"]

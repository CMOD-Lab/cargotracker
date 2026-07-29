# ============================================================
# Stage 1: Build Stage
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy source code
COPY src ./src

# Build the WAR (using payara profile by default)
RUN mvn clean package -DskipTests -Ppayara

# ============================================================
# Stage 2: Runtime Stage
# ============================================================
FROM eclipse-temurin:11-jdk

LABEL maintainer="Eclipse Cargo Tracker"
LABEL description="Eclipse Cargo Tracker - Jakarta EE Application on Payara"
LABEL version="3.1-SNAPSHOT"

# Set environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    DEPLOY_DIR=/opt/payara/glassfish/domains/production/autodeploy \
    CONFIG_DIR=/opt/payara/glassfish/domains/production/config \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create non-root user
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Download and install Payara Server
RUN apt-get update && apt-get install -y --no-install-recommends unzip wget \
    && wget -q "https://nexus.payara.fish/repository/payara-community/fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip" -O /tmp/payara.zip \
    && unzip -q /tmp/payara.zip -d /opt \
    && mv /opt/payara6 ${PAYARA_HOME} \
    && rm /tmp/payara.zip \
    && apt-get remove -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Copy the built WAR from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Copy post-boot commands
COPY post-boot-commands.asadmin ${CONFIG_DIR}/post-boot-commands.asadmin

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port and admin port
EXPOSE 8080 4848

# Start Payara with the WAR deployed
CMD ["bin/startInFish", "--noCluster", "--postbootcommandfile", "/opt/payara/glassfish/domains/production/config/post-boot-commands.asadmin", "--deploy", "/opt/payara/glassfish/domains/production/autodeploy/cargo-tracker.war"]

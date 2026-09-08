# ============================================================
# Stage 1: Build Stage
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cached layer)
RUN mvn dependency:go-offline -B -P payara

# Copy source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (using payara profile for H2 embedded DB)
RUN mvn clean package -DskipTests -P payara

# ============================================================
# Stage 2: Runtime Stage
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker"
LABEL description="Eclipse Cargo Tracker - Jakarta EE application on Payara Micro"
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
RUN mkdir -p ${PAYARA_HOME} ${DEPLOY_DIR} /opt/payara/config /opt/cargo-tracker-data && \
    chown -R payara:payara ${PAYARA_HOME} /opt/cargo-tracker-data

WORKDIR ${PAYARA_HOME}

# Download Payara Micro
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -fsSL "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -o ${PAYARA_HOME}/payara-micro.jar

# Copy the built WAR from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME} /opt/cargo-tracker-data

# Switch to non-root user
USER payara

# Expose application port
EXPOSE 8080

# Start Payara Micro
ENTRYPOINT ["sh", "-c", \
    "java ${JAVA_OPTS} \
     -jar ${PAYARA_HOME}/payara-micro.jar \
     --deploy ${DEPLOY_DIR}/cargo-tracker.war \
     --contextroot /cargo-tracker \
     --port 8080 \
     --nocluster"]

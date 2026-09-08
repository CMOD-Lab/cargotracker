# ============================================================
# Stage 1: Build Stage
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy the full project source
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (using cloud profile for PostgreSQL support)
RUN mvn clean package -Pcloud -DskipTests \
    -DpostgreSqlJdbcUrl="jdbc:postgresql://localhost:5432/postgres" \
    -DpostgreSqlUsername="postgres" \
    -DpostgreSqlPassword="postgres"

# ============================================================
# Stage 2: Runtime Stage
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker"
LABEL application="cargo-tracker"
LABEL version="3.1-SNAPSHOT"

# Environment variables
ENV PAYARA_VERSION=6.2025.3
ENV PAYARA_HOME=/opt/payara
ENV DEPLOY_DIR=${PAYARA_HOME}/glassfish/domains/domain1/autodeploy
ENV TZ=UTC
ENV LANG=en_US.UTF-8

# Create non-root user
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara

# Install Payara Server
RUN yum install -y wget unzip \
    && wget -q "https://nexus.payara.fish/repository/payara-community/fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip" \
       -O /tmp/payara.zip \
    && unzip -q /tmp/payara.zip -d /opt \
    && mv /opt/payara6 ${PAYARA_HOME} \
    && rm -f /tmp/payara.zip \
    && yum remove -y wget unzip \
    && yum clean all \
    && chown -R payara:payara ${PAYARA_HOME}

# Copy built artifacts from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/cargo-tracker.war
COPY --from=builder /workspace/target/postgresql.jar ${PAYARA_HOME}/glassfish/domains/domain1/lib/postgresql.jar

# Copy post-boot commands
COPY --from=builder /workspace/post-boot-commands.asadmin ${PAYARA_HOME}/config/post-boot-commands.asadmin

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

# Switch to non-root user
USER payara

WORKDIR ${PAYARA_HOME}

# Expose HTTP and HTTPS ports
EXPOSE 8080
EXPOSE 8181
EXPOSE 4848

# Start Payara Server
CMD ["bin/startserv"]

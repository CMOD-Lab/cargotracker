# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -DskipTests -q

# Copy source code
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (using payara profile by default)
RUN mvn clean package -DskipTests -Ppayara

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker"
LABEL application="cargo-tracker"
LABEL version="3.1-SNAPSHOT"

ENV PAYARA_VERSION=6.2025.3
ENV PAYARA_HOME=/opt/payara
ENV DEPLOY_DIR=${PAYARA_HOME}/glassfish/domains/domain1/autodeploy
ENV PAYARA_DOMAIN=domain1
ENV TZ=UTC
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"

# Install Payara Server
RUN yum install -y wget unzip \
    && wget -q https://repo1.maven.org/maven2/fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip -O /tmp/payara.zip \
    && unzip -q /tmp/payara.zip -d /opt \
    && mv /opt/payara6 ${PAYARA_HOME} \
    && rm /tmp/payara.zip \
    && yum clean all

# Create non-root user
RUN groupadd -r payara && useradd -r -g payara -d ${PAYARA_HOME} payara \
    && chown -R payara:payara ${PAYARA_HOME}

# Copy built artifacts
COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/
COPY --from=builder /workspace/post-boot-commands.asadmin ${PAYARA_HOME}/config/

# Set ownership
RUN chown -R payara:payara ${PAYARA_HOME}

USER payara

WORKDIR ${PAYARA_HOME}

EXPOSE 8080 8181 4848

CMD ["bin/startserv"]

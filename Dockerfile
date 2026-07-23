# ============================================================
# Stage 1: Build
# ============================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy dependency descriptor first for layer caching
COPY pom.xml .

# Download dependencies (offline cache layer)
RUN mvn dependency:go-offline -B -q

# Copy full source (excluding files listed in .dockerignore)
COPY src ./src
COPY post-boot-commands.asadmin .

# Build the WAR (default payara profile uses H2 embedded)
RUN mvn clean package -DskipTests -B -q

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM amazoncorretto:11

LABEL maintainer="Eclipse Cargo Tracker"
LABEL description="Eclipse Cargo Tracker - Jakarta EE application on Payara Micro"

# Install Payara Micro
ENV PAYARA_VERSION=6.2025.3
ENV PAYARA_JAR=/opt/payara/payara-micro.jar

RUN mkdir -p /opt/payara /opt/payara/config /deployments /cargo-tracker-data

# Download Payara Micro
RUN yum install -y wget && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
         -O ${PAYARA_JAR} && \
    yum remove -y wget && \
    yum clean all && \
    rm -rf /var/cache/yum

# Copy built WAR from builder stage
COPY --from=builder /workspace/target/cargo-tracker.war /deployments/cargo-tracker.war
COPY --from=builder /workspace/post-boot-commands.asadmin /opt/payara/config/post-boot-commands.asadmin

# Create non-root user for security
RUN groupadd -r payara && useradd -r -g payara -d /opt/payara payara && \
    chown -R payara:payara /opt/payara /deployments /cargo-tracker-data

USER payara

# Application port
EXPOSE 8080

# Environment variables
ENV TZ=UTC
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions"
ENV DB_JDBC_URL="jdbc:h2:file:/cargo-tracker-data/cargo-tracker-database"
ENV DB_USER=""
ENV DB_PASSWORD=""
ENV GRAPH_TRAVERSAL_URL="http://localhost:8080/cargo-tracker/rest/graph-traversal/shortest-path"

ENTRYPOINT ["sh", "-c", \
  "java ${JAVA_OPTS} -jar ${PAYARA_JAR} \
   --deploy /deployments/cargo-tracker.war \
   --postbootcommandfile /opt/payara/config/post-boot-commands.asadmin \
   --port 8080"]

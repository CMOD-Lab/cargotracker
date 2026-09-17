# =============================================================================
# Stage 1: CSS minification (PostCSS + cssnano)
# =============================================================================
FROM node:20-alpine AS css-minifier

WORKDIR /css-build

COPY src/main/webapp/resources/css/ ./src/css/
COPY src/main/webapp/resources/leaflet/leaflet.css ./src/leaflet/leaflet.css
COPY postcss.config.js ./
COPY package.json ./

RUN npm install

RUN mkdir -p dist/css dist/leaflet && \
    for f in src/css/*.css; do \
      npx postcss "$f" \
        --config . \
        --no-map \
        -o "dist/css/$(basename $f)"; \
    done && \
    npx postcss src/leaflet/leaflet.css \
      --config . \
      --no-map \
      -o dist/leaflet/leaflet.css

# =============================================================================
# Stage 2: HTML minification (html-minifier-terser)
# =============================================================================
FROM node:20-alpine AS html-minifier

WORKDIR /html-build

RUN npm install -g html-minifier-terser@7

COPY src/main/java/ ./src/main/java/

RUN find ./src/main/java -name "package.html" | while read f; do \
      html-minifier-terser \
        --collapse-whitespace \
        --remove-comments \
        --remove-redundant-attributes \
        --remove-empty-attributes \
        --minify-js true \
        --minify-css true \
        --output "$f" \
        "$f"; \
    done

# =============================================================================
# Stage 3: Maven build
# =============================================================================
FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml ./

# Download dependencies (cache layer)
RUN mvn dependency:go-offline -Pcloud -q --no-transfer-progress || true

# Copy full project source
COPY src/ ./src/
COPY post-boot-commands.asadmin ./

# Overwrite unminified CSS with minified versions from Stage 1
COPY --from=css-minifier /css-build/dist/css/ ./src/main/webapp/resources/css/
COPY --from=css-minifier /css-build/dist/leaflet/leaflet.css ./src/main/webapp/resources/leaflet/leaflet.css

# Overwrite unminified HTML with minified versions from Stage 2
COPY --from=html-minifier /html-build/src/main/java/ ./src/main/java/

# Build the WAR (cloud profile includes PostgreSQL JDBC driver)
RUN mvn clean package -Pcloud -DskipTests --no-transfer-progress

# =============================================================================
# Stage 4: Production runtime image
# Explicit base image: mcr.microsoft.com/openjdk/jdk:11-ubuntu
# Payara Micro is used as a self-contained runtime (no full server install needed)
# =============================================================================
FROM mcr.microsoft.com/openjdk/jdk:11-ubuntu

# Environment variables
ENV PAYARA_VERSION=6.2025.3 \
    PAYARA_HOME=/opt/payara \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Xms256m -Xmx512m"

# Install minimal required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Download Payara Micro JAR
RUN mkdir -p ${PAYARA_HOME} && \
    wget -q "https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/${PAYARA_VERSION}/payara-micro-${PAYARA_VERSION}.jar" \
        -O ${PAYARA_HOME}/payara-micro.jar

# Create non-root user for security
RUN groupadd -r payara && \
    useradd -r -g payara -d ${PAYARA_HOME} -s /bin/bash payara && \
    chown -R payara:payara ${PAYARA_HOME}

# Copy application artifacts from builder stage
COPY --from=builder /workspace/target/postgresql.jar /tmp/
COPY --from=builder /workspace/target/cargo-tracker.war /tmp/
COPY post-boot-commands.asadmin ${PAYARA_HOME}/

RUN chown payara:payara /tmp/postgresql.jar /tmp/cargo-tracker.war ${PAYARA_HOME}/post-boot-commands.asadmin

USER payara

WORKDIR ${PAYARA_HOME}

# Expose application port
EXPOSE 8080

# Start Payara Micro with the WAR
CMD ["java", \
     "-XX:+UseContainerSupport", \
     "-XX:MaxRAMPercentage=75.0", \
     "-Xms256m", \
     "-Xmx512m", \
     "-jar", "/opt/payara/payara-micro.jar", \
     "--addLibs", "/tmp/postgresql.jar", \
     "--postbootcommandfile", "/opt/payara/post-boot-commands.asadmin", \
     "--deploy", "/tmp/cargo-tracker.war", \
     "--port", "8080"]

FROM maven:3.9.4-eclipse-temurin-11 AS builder

WORKDIR /workspace

COPY pom.xml ./
RUN mvn dependency:go-offline -DskipTests

COPY src ./src
RUN mvn clean package -DskipTests -Pcloud

FROM mcr.microsoft.com/openjdk/jdk:11-ubuntu

ENV APP_HOME=/opt/cargo-tracker \
    DEPLOY_DIR=/opt/payara/deployments \
    PAYARA_DIR=/opt/payara \
    PAYARA_VERSION=6.2025.3 \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:+UnlockExperimentalVMOptions -XX:MaxRAMPercentage=75.0 -Dfile.encoding=UTF-8 -Duser.timezone=UTC" \
    SPRING_PROFILES_ACTIVE=docker \
    POSTGRESQL_JDBC_URL=jdbc:postgresql://postgres.example.internal:5432/cargotracker \
    POSTGRESQL_USERNAME=cargotracker \
    POSTGRESQL_PASSWORD=changeit \
    GRAPH_TRAVERSAL_URL=http://localhost:8080/rest/graph-traversal/shortest-path

WORKDIR /opt

RUN useradd --system --uid 1001 --create-home --home-dir ${APP_HOME} --shell /usr/sbin/nologin appuser \
    && mkdir -p ${DEPLOY_DIR} ${APP_HOME} \
    && curl -fsSL -o /tmp/payara-micro.jar https://repo1.maven.org/maven2/fish/payara/extras/payara-micro/6.2025.3/payara-micro-6.2025.3.jar \
    && mv /tmp/payara-micro.jar ${PAYARA_DIR}.jar \
    && chown -R appuser:appuser ${APP_HOME} ${DEPLOY_DIR} ${PAYARA_DIR}.jar

COPY --from=builder /workspace/target/cargo-tracker.war ${DEPLOY_DIR}/ROOT.war
COPY --from=builder /workspace/target/postgresql.jar ${APP_HOME}/postgresql.jar

USER appuser

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /opt/payara.jar --deploy /opt/payara/deployments/ROOT.war --contextRoot / --nocluster --addLibs /opt/cargo-tracker/postgresql.jar --autoBindHttp --port 8080 --secretsdir /opt/cargo-tracker/secrets --systemProperties db.driverClass=org.postgresql.ds.PGPoolingDataSource:webapp.graphTraversalUrl=${GRAPH_TRAVERSAL_URL}:db.jdbcUrl=${POSTGRESQL_JDBC_URL}:db.user=${POSTGRESQL_USERNAME}:db.password=${POSTGRESQL_PASSWORD}"]

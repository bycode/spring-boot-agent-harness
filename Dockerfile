# Stage 1: Build
FROM eclipse-temurin:25.0.2_10-jdk-alpine AS build
WORKDIR /app

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
COPY spotbugs-exclude.xml pmd-ruleset.xml ./
RUN ./mvnw dependency:go-offline -q

COPY src/ src/
RUN ./mvnw package -q -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:25.0.2_10-jre-alpine
WORKDIR /app

RUN addgroup -S app && adduser -S app -G app
COPY --from=build /app/target/*.jar app.jar
RUN chown app:app app.jar

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]

# Use a Maven + JDK 17 image that works with Spring PetClinic
FROM maven:3.9.0-eclipse-temurin-17 AS build

WORKDIR /workspace

# Clone Spring PetClinic repo (or assume local code in src/)
ARG REPO_URL=https://github.com/spring-projects/spring-petclinic.git
RUN git clone --depth 1 $REPO_URL app || true

WORKDIR /workspace/app

# Build the project (skip tests)
RUN mvn clean package -DskipTests

# Runtime image
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy jar from build stage
COPY --from=build /workspace/app/target/*.jar app.jar

EXPOSE 8080
CMD ["java", "-jar", "app.jar"]

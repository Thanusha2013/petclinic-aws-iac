# Use Maven to build
FROM maven:3.9.0-eclipse-temurin-17 AS build
WORKDIR /workspace

# Clone repo if needed
ARG REPO_URL=https://github.com/spring-projects/spring-petclinic.git
RUN git clone --depth 1 $REPO_URL app
WORKDIR /workspace/app

# Build Spring PetClinic
RUN mvn -DskipTests package

# Final runtime image
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]

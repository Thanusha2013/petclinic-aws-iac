# -----------------------------
# Stage 1: Build the application
# -----------------------------
FROM maven:3.9.0-eclipse-temurin-17 AS build

# Set working directory
WORKDIR /workspace/app

# Copy the source code into the container
COPY ./src ./src
COPY ./pom.xml .

# Build the Spring PetClinic project
RUN mvn clean package -DskipTests

# -----------------------------
# Stage 2: Runtime image
# -----------------------------
FROM eclipse-temurin:17-jre

# Set working directory
WORKDIR /app

# Copy the built JAR from the build stage
COPY --from=build /workspace/app/target/*.jar app.jar

# Expose application port
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "app.jar"]

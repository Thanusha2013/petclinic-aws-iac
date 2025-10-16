# Use OpenJDK 25 base image and install Maven manually
FROM eclipse-temurin:25-jdk AS build

# Install Maven
RUN apt-get update && apt-get install -y maven git && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Clone the app source
ARG REPO_URL=https://github.com/spring-projects/spring-petclinic.git
RUN git clone --depth 1 $REPO_URL app || true
WORKDIR /workspace/app

# Build Spring PetClinic
RUN mvn -DskipTests package

# Final runtime image
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /workspace/app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

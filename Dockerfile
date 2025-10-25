# Build image with Maven and Java 25
FROM maven:3.9.9-eclipse-temurin-25 AS build
WORKDIR /workspace

# Clone Spring PetClinic
ARG REPO_URL=https://github.com/spring-projects/spring-petclinic.git
RUN git clone --depth 1 $REPO_URL app
WORKDIR /workspace/app

# Build the app
RUN mvn -DskipTests package

# Runtime image
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /workspace/app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]

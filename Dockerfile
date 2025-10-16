# Dockerfile for Spring PetClinic - expects source code at repo root or set up as submodule
FROM maven:3.9.9-eclipse-temurin-25 AS build
WORKDIR /workspace
# clone the spring-petclinic repo if user doesn't provide source locally
ARG REPO_URL=https://github.com/spring-projects/spring-petclinic.git
RUN git clone --depth 1 $REPO_URL app || true
WORKDIR /workspace/app
RUN mvn -DskipTests package

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /workspace/app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]

# Note: CI builds in GitHub Actions will build the docker image from repository root.

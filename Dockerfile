FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
RUN git clone --depth 1 https://github.com/spring-projects/spring-petclinic.git app
WORKDIR /workspace/app
RUN mvn -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

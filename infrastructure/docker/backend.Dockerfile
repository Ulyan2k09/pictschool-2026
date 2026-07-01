FROM eclipse-temurin:17-jdk AS build
WORKDIR /app/backend
COPY backend/ ./
RUN chmod +x ./gradlew && ./gradlew installDist --no-daemon

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/backend/build/install/duck-round-backend/ ./
EXPOSE 8080
CMD ["./bin/duck-round-backend"]

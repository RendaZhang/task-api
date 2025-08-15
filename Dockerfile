# ---------- Build stage ----------
FROM maven:3.9.8-eclipse-temurin-21 AS build
WORKDIR /build

# 优化缓存：分步复制 pom.xml 和源码
COPY pom.xml .
RUN mvn -q -B -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -q -B -DskipTests package

# ---------- Runtime stage ----------
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# 使用最小用户和权限
RUN apk add --no-cache shadow && \
    useradd -r -u 10001 app && \
    chown -R app /app && \
    apk del shadow
USER app

# 复制构建产物（明确 JAR 名称）
COPY --from=build /build/target/task-api-0.1.0.jar /app/app.jar

EXPOSE 8080
ENV JAVA_OPTS=""

# 安装 curl 并添加健康检查
RUN apk add --no-cache curl
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -s http://127.0.0.1:8080/actuator/health || exit 1

ENTRYPOINT ["sh","-lc","exec java $JAVA_OPTS -jar /app/app.jar"]

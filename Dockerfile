# ---------- Build stage ----------
FROM maven:3.9.8-eclipse-temurin-21 AS build
WORKDIR /build

# 先拷 pom 走离线依赖，提升缓存命中
COPY pom.xml .
RUN mvn -q -B -DskipTests dependency:go-offline

# 再拷源码并打包
COPY src ./src
RUN mvn -q -B -DskipTests package

# ---------- Runtime stage ----------
FROM eclipse-temurin:21-jre
WORKDIR /app

# 最小权限运行
RUN useradd -r -u 10001 app && chown -R app /app
USER app

# 复制构建产物（粗暴稳定：只有一个可执行jar）
COPY --from=build /build/target/*-SNAPSHOT.jar /app/app.jar 2>/dev/null || \
    COPY --from=build /build/target/*0.1.0.jar /app/app.jar

EXPOSE 8080
ENV JAVA_OPTS=""

# 可选：健康检查（容器层面；K8s里仍以 probe 为准）
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/actuator/health || exit 1

ENTRYPOINT ["sh","-lc","exec java $JAVA_OPTS -jar /app/app.jar"]

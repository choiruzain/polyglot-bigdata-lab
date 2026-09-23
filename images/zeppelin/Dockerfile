# syntax=docker/dockerfile:1
ARG TOOLS_IMAGE=dataplatform/tools:local
FROM ${TOOLS_IMAGE} AS build
USER root
ARG ZEPPELIN_COMMIT=9de50ac36e15704642c34f9c41835deb2dd95efc
ARG ZEPPELIN_SHA256=246ee29caea0c45ae7c37f61b7c48cd7272943730934d6ba3d631dd37e910c8c
RUN apt-get update && apt-get install -y --no-install-recommends git unzip && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN curl -fsSL "https://codeload.github.com/pan3793/zeppelin/tar.gz/${ZEPPELIN_COMMIT}" -o /tmp/source.tgz \
 && echo "${ZEPPELIN_SHA256}  /tmp/source.tgz" | sha256sum -c - \
 && tar -xzf /tmp/source.tgz --strip-components=1 && rm /tmp/source.tgz
ENV MAVEN_OPTS="-Xmx2g -XX:ReservedCodeCacheSize=512m"
# The upstream postinstall downloads E2E browsers even when Maven tests are
# skipped. These browsers are unnecessary in the runtime image and unsupported
# by upstream Playwright on Ubuntu 26 ARM64. Preserve all actual UI build steps.
RUN python3 -c 'import json; from pathlib import Path; p=Path("zeppelin-web-angular/package.json"); d=json.loads(p.read_text()); old=d["scripts"]["postinstall"]; assert " && npx playwright install --with-deps" in old; d["scripts"]["postinstall"]=old.replace(" && npx playwright install --with-deps", ""); p.write_text(json.dumps(d, indent=2)+"\n")'
# Match the actual Spark 4.1.3 distribution's Scala compiler, not the PR's 2.13.18 default.
RUN --mount=type=cache,target=/root/.m2 --mount=type=cache,target=/root/.npm \
 ./mvnw -B -ntp install -pl zeppelin-server,spark/interpreter -am \
 -DskipTests -Pspark-4.1 -Pspark-scala-2.13 -Dspark.scala.version=2.13.17
RUN --mount=type=cache,target=/root/.m2 --mount=type=cache,target=/root/.npm \
 ./mvnw -B -ntp install -pl zeppelin-web-angular,zeppelin-distribution -DskipTests \
 && ./mvnw -B -ntp -pl zeppelin-distribution assembly:single

# The Scala REPL adapter is loaded dynamically, so Maven's -am does not pull it
# in as a dependency of spark/interpreter. Package it explicitly.
RUN --mount=type=cache,target=/root/.m2 \
 ./mvnw -B -ntp install -pl spark/spark-scala-parent -DskipTests \
 && ./mvnw -B -ntp package -pl spark/scala-2.13 -DskipTests -Dspark.scala.version=2.13.17 \
 && ./mvnw -B -ntp -pl zeppelin-distribution assembly:single

FROM ${TOOLS_IMAGE}
USER root
LABEL org.opencontainers.image.title="Polyglot Zeppelin Spark 4.1.3 experiment" \
      org.opencontainers.image.source="https://github.com/apache/zeppelin/pull/5465" \
      org.opencontainers.image.revision="9de50ac36e15704642c34f9c41835deb2dd95efc"
COPY --from=build --chown=student:student /src/zeppelin-distribution/target/zeppelin-0.13.0-SNAPSHOT-bin/zeppelin-0.13.0-SNAPSHOT-bin /opt/zeppelin
RUN grep -q 'Spark 4.1.3 ' /opt/spark/RELEASE \
 && test -f /opt/spark/jars/scala-library-2.13.17.jar
ENV ZEPPELIN_HOME=/opt/zeppelin \
    ZEPPELIN_ADDR=0.0.0.0 \
    ZEPPELIN_PORT=8080 \
    ZEPPELIN_MEM="-Xms128m -Xmx768m" \
    ZEPPELIN_NOTEBOOK_DIR=/opt/zeppelin/notebook \
    HADOOP_USER_NAME=student \
    HADOOP_CONF_DIR=/opt/hadoop-conf
USER student
WORKDIR /opt/zeppelin
EXPOSE 8080
CMD ["/opt/zeppelin/bin/zeppelin.sh"]

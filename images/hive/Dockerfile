FROM eclipse-temurin:21-jre

ARG HIVE_VERSION=4.2.1
ARG HADOOP_VERSION=3.4.1
ARG PG_JDBC_VERSION=42.7.7
ARG HIVE_URL=https://downloads.apache.org/hive/hive-${HIVE_VERSION}
ARG HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}
ARG PG_JDBC_URL=https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_JDBC_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates procps \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1501 hive \
 && mkdir /opt/hive /opt/hadoop && chown hive:hive /opt/hive /opt/hadoop

USER hive
WORKDIR /home/hive

RUN set -eux; \
    curl -fsSL -o /tmp/h.tgz "${HADOOP_URL}/hadoop-${HADOOP_VERSION}.tar.gz"; \
    curl -fsSL -o /tmp/h.sha "${HADOOP_URL}/hadoop-${HADOOP_VERSION}.tar.gz.sha512"; \
    echo "$(grep -oE '[0-9a-fA-F]{128}' /tmp/h.sha | head -n1)  /tmp/h.tgz" | sha512sum -c -; \
    tar -xzf /tmp/h.tgz -C /opt/hadoop --strip-components=1; \
    rm -f /tmp/h.tgz /tmp/h.sha; rm -rf /opt/hadoop/share/doc

RUN set -eux; \
    curl -fsSL -o /tmp/hive.tgz "${HIVE_URL}/apache-hive-${HIVE_VERSION}-bin.tar.gz"; \
    curl -fsSL -o /tmp/hive.sha "${HIVE_URL}/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256"; \
    echo "$(grep -oE '[0-9a-fA-F]{64}' /tmp/hive.sha | head -n1)  /tmp/hive.tgz" | sha256sum -c -; \
    tar -xzf /tmp/hive.tgz -C /opt/hive --strip-components=1; \
    rm -f /tmp/hive.tgz /tmp/hive.sha

RUN set -eux; \
    jar="/opt/hive/lib/postgresql-${PG_JDBC_VERSION}.jar"; \
    curl -fsSL -o "${jar}" "${PG_JDBC_URL}/postgresql-${PG_JDBC_VERSION}.jar"; \
    curl -fsSL -o /tmp/pg.sha1 "${PG_JDBC_URL}/postgresql-${PG_JDBC_VERSION}.jar.sha1"; \
    echo "$(cut -c1-40 /tmp/pg.sha1)  ${jar}" | sha1sum -c -; \
    rm -f /tmp/pg.sha1

ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV PATH="/opt/hive/bin:/opt/hadoop/bin:${PATH}"

COPY --chown=hive:hive --chmod=755 entrypoint.sh /opt/hive/entrypoint.sh

USER root
RUN mkdir /opt/tez && chown hive:hive /opt/tez
USER hive

ARG TEZ_VERSION=0.10.5
ARG TEZ_URL=https://downloads.apache.org/tez/${TEZ_VERSION}
RUN set -eux; \
    curl -fsSL -o /tmp/tez.tgz "${TEZ_URL}/apache-tez-${TEZ_VERSION}-bin.tar.gz"; \
    curl -fsSL -o /tmp/tez.sha "${TEZ_URL}/apache-tez-${TEZ_VERSION}-bin.tar.gz.sha512"; \
    echo "$(grep -oE '[0-9a-fA-F]{128}' /tmp/tez.sha | head -n1)  /tmp/tez.tgz" | sha512sum -c -; \
    tar -xzf /tmp/tez.tgz -C /opt/tez --strip-components=1; \
    rm -f /tmp/tez.tgz /tmp/tez.sha; \
    rm -rf /opt/tez/lib/hadoop-common-* /opt/tez/lib/hadoop-hdfs-* /opt/tez/lib/hadoop-mapreduce-client-* /opt/tez/lib/hadoop-yarn-* /opt/tez/lib/hadoop-auth-* /opt/tez/lib/hadoop-annotations-* /opt/tez/lib/slf4j-*; \
    mkdir -p /opt/tez/conf

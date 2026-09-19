FROM eclipse-temurin:17-jdk

ARG SPARK_VERSION=4.1.3
ARG SPARK_URL=https://downloads.apache.org/spark/spark-${SPARK_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates procps python3 python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1502 student \
 && mkdir /opt/spark && chown student:student /opt/spark

USER student
WORKDIR /home/student

RUN set -eux; \
    curl -fsSL -o /tmp/spark.tgz "${SPARK_URL}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"; \
    curl -fsSL -o /tmp/spark.sha "${SPARK_URL}/spark-${SPARK_VERSION}-bin-hadoop3.tgz.sha512"; \
    expected="$(tr -d ' \n\r' < /tmp/spark.sha | tr 'A-F' 'a-f' | grep -oE '[0-9a-f]{128}' | head -n1)"; \
    echo "${expected}  /tmp/spark.tgz" | sha512sum -c -; \
    tar -xzf /tmp/spark.tgz -C /opt/spark --strip-components=1; \
    rm -f /tmp/spark.tgz /tmp/spark.sha

ENV SPARK_HOME=/opt/spark
ENV PATH="/opt/spark/bin:${PATH}"
ENV PYSPARK_PYTHON=python3

RUN mkdir -p /home/student/.ivy2

RUN python3 -m venv /home/student/venv \
 && /home/student/venv/bin/pip install --no-cache-dir jupyterlab pandas pyarrow numpy matplotlib
RUN ln -s "$(ls /opt/spark/python/lib/py4j-*-src.zip | head -n1)" /opt/spark/python/lib/py4j-src.zip
ENV PATH="/home/student/venv/bin:${PATH}"
ENV PYTHONPATH="/opt/spark/python:/opt/spark/python/lib/py4j-src.zip"

# Bake the Hive 4.1.0 metastore client jars into the image: no download at run time, works offline
USER root
RUN mkdir /opt/hive-client && chown student:student /opt/hive-client
USER student
COPY --chown=student:student resolve_hive_client.py /tmp/resolve_hive_client.py
RUN set -eux; \
    spark-submit /tmp/resolve_hive_client.py || true; \
    n="$(ls /home/student/.ivy2.5.2/jars/*.jar | wc -l)"; \
    echo "resolved jars: ${n}"; \
    test "${n}" -gt 200; \
    cp /home/student/.ivy2.5.2/jars/*.jar /opt/hive-client/; \
    rm -rf /home/student/.ivy2.5.2/* /tmp/resolve_hive_client.py /tmp/hsperfdata_student

# sbt for compiling Scala Spark jobs
USER root
RUN mkdir /opt/sbt && chown student:student /opt/sbt
USER student
ARG SBT_VERSION=1.12.14
ARG SBT_URL=https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}
RUN set -eux; \
    curl -fsSL -o /tmp/sbt.tgz "${SBT_URL}/sbt-${SBT_VERSION}.tgz"; \
    curl -fsSL -o /tmp/sbt.sha "${SBT_URL}/sbt-${SBT_VERSION}.tgz.sha256"; \
    echo "$(grep -oE '[0-9a-fA-F]{64}' /tmp/sbt.sha | head -n1)  /tmp/sbt.tgz" | sha256sum -c -; \
    tar -xzf /tmp/sbt.tgz -C /opt/sbt --strip-components=1; \
    rm -f /tmp/sbt.tgz /tmp/sbt.sha
ENV PATH="/opt/sbt/bin:${PATH}"
ENV SBT_OPTS="-Xmx1g"

# SQL clients and Python database drivers
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client mysql-client \
 && rm -rf /var/lib/apt/lists/*
USER student
RUN pip install --no-cache-dir "psycopg[binary]" mysql-connector-python sqlalchemy


# JDBC drivers for Spark (PostgreSQL, MySQL)
ARG PG_JDBC_VERSION=42.7.13
ARG MYSQL_JDBC_VERSION=26.7.0
COPY --chown=student:student --chmod=755 fetch_jar.sh /tmp/fetch_jar.sh
RUN /tmp/fetch_jar.sh org/postgresql/postgresql/${PG_JDBC_VERSION}/postgresql-${PG_JDBC_VERSION}.jar /opt/spark/jars \
 && /tmp/fetch_jar.sh com/mysql/mysql-connector-j/${MYSQL_JDBC_VERSION}/mysql-connector-j-${MYSQL_JDBC_VERSION}.jar /opt/spark/jars \
 && rm -f /tmp/fetch_jar.sh

RUN pip install --no-cache-dir pymongo

# MongoDB Spark Connector (jars resolved once at build time)
ARG MONGO_SPARK_VERSION=11.1.0
COPY --chown=student:student --chmod=755 install_mongo_connector.sh /tmp/install_mongo_connector.sh
RUN /tmp/install_mongo_connector.sh ${MONGO_SPARK_VERSION} && rm -f /tmp/install_mongo_connector.sh

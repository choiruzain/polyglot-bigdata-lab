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

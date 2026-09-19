FROM eclipse-temurin:17-jre

ARG TARGETARCH
ARG HADOOP_VERSION=3.5.0
ARG HADOOP_URL=https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates procps \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1500 hadoop \
 && mkdir /opt/hadoop && chown hadoop:hadoop /opt/hadoop

USER hadoop
WORKDIR /home/hadoop

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) f="hadoop-${HADOOP_VERSION}.tar.gz" ;; \
      arm64) f="hadoop-${HADOOP_VERSION}-aarch64.tar.gz" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/hadoop.tgz "${HADOOP_URL}/${f}"; \
    curl -fsSL -o /tmp/hadoop.tgz.sha512 "${HADOOP_URL}/${f}.sha512"; \
    expected="$(grep -oE '[0-9a-fA-F]{128}' /tmp/hadoop.tgz.sha512 | head -n1)"; \
    echo "${expected}  /tmp/hadoop.tgz" | sha512sum -c -; \
    tar -xzf /tmp/hadoop.tgz -C /opt/hadoop --strip-components=1; \
    rm -f /tmp/hadoop.tgz /tmp/hadoop.tgz.sha512; \
    rm -rf /opt/hadoop/share/doc

ENV HADOOP_HOME=/opt/hadoop
ENV PATH="${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}"

RUN mkdir -p /opt/hadoop/data/namenode /opt/hadoop/data/datanode
COPY --chown=hadoop:hadoop --chmod=755 entrypoint.sh /opt/hadoop/entrypoint.sh

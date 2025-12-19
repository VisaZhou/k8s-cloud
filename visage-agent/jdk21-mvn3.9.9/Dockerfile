FROM crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/inbound-agent:3327.v868139a_d00e0-7

USER root

# ========= 安装 Java 21 =========
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        git \
        bash \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# 安装 Temurin Java 21
RUN wget -O /tmp/jdk21.tar.gz \
      https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz \
    && mkdir -p /opt/java \
    && tar -xzf /tmp/jdk21.tar.gz -C /opt/java --strip-components=1 \
    && rm /tmp/jdk21.tar.gz

ENV JAVA_HOME=/opt/java
ENV PATH=$JAVA_HOME/bin:$PATH

# ========= 安装 Maven 3.9.9 =========
RUN wget -O /tmp/maven.tar.gz \
      https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz \
    && mkdir -p /opt/maven \
    && tar -xzf /tmp/maven.tar.gz -C /opt/maven --strip-components=1 \
    && rm /tmp/maven.tar.gz

ENV MAVEN_HOME=/opt/maven
ENV PATH=$MAVEN_HOME/bin:$PATH

# ========= 验证 =========
RUN java -version && mvn -v && git --version

USER jenkins
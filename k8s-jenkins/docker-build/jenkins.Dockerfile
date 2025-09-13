FROM crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/jenkins:lts

USER root

# 替换 Debian 12 (bookworm) 的官方源为阿里云源
RUN sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://security.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources && \
    apt-get clean && apt-get update

# 安装构建工具
RUN apt-get install -y \
        openjdk-17-jdk \
        maven \
        git \
        nodejs \
        npm \
        curl \
        unzip \
        docker.io \
        ca-certificates && \
    curl -fsSL https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar zx && \
    mv linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 使用华为云的 Jenkins 更新中心
ENV JENKINS_UC=https://updates.jenkins.io/update-center.json

USER jenkins
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/plugins.txt

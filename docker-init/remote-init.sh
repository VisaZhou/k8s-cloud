#!/bin/bash

LOCAL_FILE="/root/docker-compose"
TARGET_PATH="/usr/local/bin/"

# Docker 安装
yum -y install docker
systemctl start docker
systemctl enable docker
docker --version

# Docker-Compose 安装
cp "$LOCAL_FILE" "$TARGET_PATH"docker-compose
sudo chmod +x "$TARGET_PATH"docker-compose
docker-compose version
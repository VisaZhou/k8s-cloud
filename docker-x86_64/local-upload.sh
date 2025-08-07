#!/bin/bash

LOCAL_FILE="/Users/zhouxujin/Downloads/docker-compose"
REMOTE_USER="root"
REMOTE_HOST="113.44.50.184"
REMOTE_PATH="/root/"
PASSWORD="Zxj201328"

# 设置代理
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
# 下载 Docker Compose 到本地
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o "$LOCAL_FILE"
# 上传 Docker Compose 到远程服务器
sshpass -p "$PASSWORD" rsync -avz "$LOCAL_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

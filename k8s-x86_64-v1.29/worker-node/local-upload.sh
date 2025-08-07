#!/bin/bash

# ========== 配置 ==========
REMOTE_USER="root"
REMOTE_HOST="113.44.50.184"
REMOTE_PATH="/root/"
PASSWORD="Zxj201328"
DOWNLOAD_DIR="/Users/zhouxujin/Downloads"

# ========== 网络代理 ==========
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890

# ========== 下载文件 ==========
echo "下载 containerd..."
curl -Lo "$DOWNLOAD_DIR/containerd-1.7.15-linux-amd64.tar.gz" https://github.com/containerd/containerd/releases/download/v1.7.15/containerd-1.7.15-linux-amd64.tar.gz

echo "下载 containerd.service..."
curl -Lo "$DOWNLOAD_DIR/containerd.service" https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

echo "下载 runc..."
curl -Lo "$DOWNLOAD_DIR/runc" https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64

echo "下载 nerdctl..."
curl -Lo "$DOWNLOAD_DIR/nerdctl-1.7.6-linux-amd64.tar.gz" https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-1.7.6-linux-amd64.tar.gz

echo "下载 buildkit..."
curl -Lo "$DOWNLOAD_DIR/buildkit-v0.12.5.linux-amd64.tar.gz" https://github.com/moby/buildkit/releases/download/v0.12.5/buildkit-v0.12.5.linux-amd64.tar.gz

echo "下载 kube-flannel.yml..."
curl -Lo "$DOWNLOAD_DIR/kube-flannel.yml" https://raw.githubusercontent.com/flannel-io/flannel/v0.25.1/Documentation/kube-flannel.yml

# ========== 上传文件 ==========
echo "上传所有文件到远程服务器 $REMOTE_HOST:$REMOTE_PATH ..."
for file in containerd-1.7.15-linux-amd64.tar.gz containerd.service runc nerdctl-1.7.6-linux-amd64.tar.gz buildkit-v0.12.5.linux-amd64.tar.gz kube-flannel.yml
do
    echo "→ 上传 $file"
    sshpass -p "$PASSWORD" rsync -avz "$DOWNLOAD_DIR/$file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
done

echo "所有文件已成功上传至 $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
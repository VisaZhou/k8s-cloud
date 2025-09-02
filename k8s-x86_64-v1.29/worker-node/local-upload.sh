#!/bin/bash

# ========== 配置 ==========
REMOTE_USER="root"
REMOTE_HOST="117.72.153.178"
REMOTE_PATH="/root"
PASSWORD="Zxj201328"
DOWNLOAD_DIR="/Users/zhouxujin/Downloads"

K8S_VERSION="v1.29.15"

# ========== 网络代理 ==========
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890

# ===================== 下载 Kubernetes 二进制 =====================
FILES=(
"kubeadm"
"kubectl"
"kubelet"
"containerd-1.7.15-linux-amd64.tar.gz"
"containerd.service"
"runc"
"nerdctl-1.7.6-linux-amd64.tar.gz"
"buildkit-v0.12.5.linux-amd64.tar.gz"
"kube-flannel.yml"
"crictl-v1.27.0-linux-amd64.tar.gz"
)

URLS=(
"https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm"
"https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
"https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet"
"https://github.com/containerd/containerd/releases/download/v1.7.15/containerd-1.7.15-linux-amd64.tar.gz"
"https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"
"https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64"
"https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-1.7.6-linux-amd64.tar.gz"
"https://github.com/moby/buildkit/releases/download/v0.12.5/buildkit-v0.12.5.linux-amd64.tar.gz"
"https://raw.githubusercontent.com/flannel-io/flannel/v0.25.1/Documentation/kube-flannel.yml"
"https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.0/crictl-v1.27.0-linux-amd64.tar.gz"
)

for i in "${!FILES[@]}"; do
if [ -f "${DOWNLOAD_DIR}/${FILES[i]}" ]; then
    # 远端文件大小
    remote_size=$(curl -sI "${URLS[i]}" | awk '/Content-Length/ {print $2}' | tr -d '\r')
    local_size=$(stat -c %s "${DOWNLOAD_DIR}/${FILES[i]}")

    if [ "$remote_size" = "$local_size" ]; then
        echo "文件 ${FILES[i]} 已经完整下载，跳过"
        continue
    fi
fi
# 断点续传
curl -C - --fail --retry 3 -Lo "${DOWNLOAD_DIR}/${FILES[i]}" "${URLS[i]}"
done

# ===================== 上传文件 =====================
for file in "${FILES[@]}"; do
    echo "上传 $file ..."
    sshpass -p "${PASSWORD}" rsync -avz --progress "${DOWNLOAD_DIR}/$file" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"
done

echo "文件上传完成"
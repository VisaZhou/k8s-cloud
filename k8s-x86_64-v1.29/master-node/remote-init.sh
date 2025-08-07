#!/bin/bash

# ========== 配置 ==========
MASTER_NAME="master-node"
SOURCE_PATH="/root"

# 关闭 Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 创建一个配置文件 /etc/modules-load.d/k8s.conf，在系统启动时加载以下两个内核模块
sudo bash -c 'cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF'
sudo modprobe overlay
sudo modprobe br_netfilter

# 配置网络转发和防火墙处理规则,确保 Kubernetes 网络流量 能被正确转发和被 iptables 处理
sudo bash -c 'cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF'
sudo sysctl --system

# 设置主节点名称
sudo hostnamectl set-hostname "$MASTER_NAME"

# 安装必要工具
sudo dnf install -y dnf-utils curl

# 添加 Kubernetes 官方 RPM 源
sudo bash -c 'cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF'

# 设置 SELinux 为 permissive 模式（Kubernetes 推荐）
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# 安装 kubelet、kubeadm 和 kubectl
sudo dnf install -y kubelet kubeadm kubectl
# 防止自动更新（锁定版本）
sudo dnf mark install kubelet kubeadm kubectl
# 启动并设置 kubelet 开机自启
sudo systemctl enable --now kubelet


# 安装 containerd（k8s 从 1.24版本开始默认不使用 docker，而是直接使用底层的 containerd）
sudo tar Cxzvf /usr/local "$SOURCE_PATH/containerd-1.7.15-linux-amd64.tar.gz"
sudo mv "$SOURCE_PATH/containerd.service" /usr/lib/systemd/system/containerd.service
# 重新加载 systemd 管理器配置
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
# 写入 /etc/containerd/config.toml，并启动 containerd 服务
sudo bash -c 'cat <<EOF > /etc/containerd/config.toml
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".containerd]
    default_runtime_name = "runc"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true

[plugins."io.containerd.internal.v1.opt"]
  path = "/opt/containerd"

[plugins."io.containerd.internal.v1.reload"]
  disabled_plugins = []
  ignored_plugins = []

[metrics]
  address = "127.0.0.1:1338"
  grpc_histogram = false

[debug]
  level = "info"
EOF'
sudo systemctl restart containerd
containerd --version


# 手动更新 containerd 中的 runc 版本，以支持现代 Linux 功能
which runc
cp /usr/bin/runc /usr/bin/runc.bak
install -m 755 "$SOURCE_PATH/runc" /usr/bin/runc
runc --version

# 安装 nerdctl（nerdctl 是 containerd 的官方兼容工具，提供类似 Docker 的 CLI 体验）
sudo tar Cxzvf /usr/local/bin "$SOURCE_PATH/nerdctl-1.7.6-linux-amd64.tar.gz"
chmod +x /usr/local/bin/nerdctl
nerdctl --version

# 安装 buildkit （buildkit 是 containerd 的官方构建工具，提供类似 Docker Build 的功能）
sudo tar Cxzvf /usr/local "$SOURCE_PATH/buildkit-v0.12.5.linux-amd64.tar.gz"
chmod +x /usr/local/bin/buildctl
buildctl --version


# 查看 kubeadm 要用哪些镜像
kubeadm config images list --kubernetes-version v1.29.15

# 镜像准备：使用 nerdctl 登录阿里云镜像仓库，为了防止与 docker 登录冲突，先删除凭据文件再用 nerdctl 登录。
rm -f ~/.docker/config.json
echo "zxj201328" | nerdctl login --username=472493922@qq.com crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com --password-stdin
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-apiserver:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-controller-manager:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-scheduler:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-proxy:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.9
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/etcd:3.5.16-0
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/coredns:v1.11.1
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-apiserver:v1.29.15 registry.k8s.io/kube-apiserver:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-controller-manager:v1.29.15 registry.k8s.io/kube-controller-manager:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-scheduler:v1.29.15 registry.k8s.io/kube-scheduler:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-proxy:v1.29.15 registry.k8s.io/kube-proxy:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.9 registry.k8s.io/pause:3.9
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/etcd:3.5.16-0 registry.k8s.io/etcd:3.5.16-0
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/coredns:v1.11.1 registry.k8s.io/coredns/coredns:v1.11.1
nerdctl -n k8s.io images

# 初始化 Kubernetes 主节点
sudo kubeadm init \
  --kubernetes-version v1.29.15 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU,Mem \
  -v=6

# root 用户操作主节点
export KUBECONFIG=/etc/kubernetes/admin.conf
# 非 root 用户操作主节点
# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 Flannel 网络插件
kubectl apply -f "$SOURCE_PATH/kube-flannel.yml"

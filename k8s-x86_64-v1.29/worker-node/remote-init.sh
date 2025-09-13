#!/bin/bash

export PATH=$PATH:/usr/local/bin

# ========== 配置 ==========
WORK_NAME="work-node-0"
SOURCE_PATH="/root"
BIN_PATH="/usr/local"
SYS_BIN_PATH="/usr/bin"

# ==================== 系统准备 ====================
# 关闭 Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
# 在系统启动时加载必要内核模块
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
sudo hostnamectl set-hostname "${WORK_NAME}"
echo "127.0.0.1 ${WORK_NAME}" | sudo tee -a /etc/hosts

# ==================== 安装基础工具 ====================
yum install -y tar wget iproute iptables conntrack

# ==================== 安装 crictl ====================
sudo tar -C ${BIN_PATH}/bin -xzvf "${SOURCE_PATH}/crictl-v1.27.0-linux-amd64.tar.gz"
sudo chmod +x ${BIN_PATH}/bin/crictl
crictl --version

# ==================== 安装 Kubernetes 二进制文件 ====================
# 安装 kubeadm、kubectl 和 kubelet
sudo install -m 755 "${SOURCE_PATH}/kubeadm" ${SYS_BIN_PATH}/kubeadm
sudo install -m 755 "${SOURCE_PATH}/kubectl" ${SYS_BIN_PATH}/kubectl
sudo install -m 755 "${SOURCE_PATH}/kubelet" ${SYS_BIN_PATH}/kubelet
# 写入 kubelet systemd 文件
sudo tee /etc/systemd/system/kubelet.service >/dev/null <<'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
# 写入 kubeadm kubelet 配置
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf >/dev/null <<'EOF'
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF
# 启动并设置 kubelet 开机自启
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet

# ==================== 安装 containerd ====================
# 安装 containerd（k8s 从 1.24版本开始默认不使用 docker，而是直接使用底层的 containerd）
sudo tar -C ${BIN_PATH} -xzvf "${SOURCE_PATH}/containerd-1.7.15-linux-amd64.tar.gz"
sudo cp -f "${SOURCE_PATH}/containerd.service" /usr/lib/systemd/system/containerd.service
# 重新加载 systemd 管理器配置
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
# 写入 containerd 配置
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
sudo install -m 755 "${SOURCE_PATH}/runc" ${BIN_PATH}/bin/runc
runc --version

# 安装 nerdctl（nerdctl 是 containerd 的官方兼容工具，提供类似 Docker 的 CLI 体验）
sudo tar -C ${BIN_PATH}/bin -xzvf "${SOURCE_PATH}/nerdctl-1.7.6-linux-amd64.tar.gz"
sudo chmod +x ${BIN_PATH}/bin/nerdctl
nerdctl --version

# 安装 buildkit （buildkit 是 containerd 的官方构建工具，提供类似 Docker Build 的功能）
sudo tar -C ${BIN_PATH} -xzvf "${SOURCE_PATH}/buildkit-v0.12.5.linux-amd64.tar.gz"
sudo chmod +x ${BIN_PATH}/bin/buildctl
buildctl --version

# 安装网络插件 CNI
sudo tar -C /opt/cni/bin -xzvf "/root/cni-plugins-linux-amd64-v1.3.0.tgz"
sudo chmod +x /opt/cni/bin/*
ls -l /opt/cni/bin

# 镜像准备：使用 nerdctl 登录阿里云镜像仓库，为了防止与 docker 登录冲突，先删除凭据文件再用 nerdctl 登录。
rm -f ~/.docker/config.json
echo "zxj201328" | nerdctl login --username=472493922@qq.com crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com --password-stdin
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-proxy:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.9
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/flannel-cni-plugin:v1.4.0-flannel1
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/flannel:v0.25.1

# 给镜像重新打标签
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-proxy:v1.29.15 registry.k8s.io/kube-proxy:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.9 registry.k8s.io/pause:3.9
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.9 registry.k8s.io/pause:3.8
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/flannel-cni-plugin:v1.4.0-flannel1 docker.io/flannel/flannel-cni-plugin:v1.4.0-flannel1
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/flannel:v0.25.1 docker.io/flannel/flannel:v0.25.1
nerdctl -n k8s.io images


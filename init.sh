#!/bin/bash

# Docker 安装，启动，设置开机启动
yum -y install docker
systemctl start docker
systemctl enable docker
docker --version

# Docker Compose 本地下载，上传，设置权限
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
#TODO curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o /Users/zhouxujin/Downloads/docker-compose
#TODO rsync -avz  /Users/zhouxujin/Downloads/docker-compose root@113.44.50.184:/usr/local/bin/
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version

# Kubernetes 主节点安装
# 关闭 Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
# 创建一个配置文件 /etc/modules-load.d/k8s.conf，在系统启动时加载以下两个内核模块
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
# 配置网络转发和防火墙处理规则,确保 Kubernetes 网络流量 能被正确转发和被 iptables 处理
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
# 设置主节点名称
sudo hostnamectl set-hostname master-node
# 安装必要工具
sudo dnf install -y dnf-utils curl
# 添加 Kubernetes 官方 RPM 源
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
# 设置 SELinux 为 permissive 模式（Kubernetes 推荐）
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
# 安装 kubelet、kubeadm 和 kubectl
sudo dnf install -y kubelet kubeadm kubectl
# 防止自动更新（锁定版本）
sudo dnf mark install kubelet kubeadm kubectl
# 启动并设置 kubelet 开机自启
sudo systemctl enable --now kubelet
# 下载 containerd 到本地，上传并安装（因为 k8s 从 1.24版本开始默认不使用 docker，而是直接使用底层的 containerd）
#TODO curl -LO https://github.com/containerd/containerd/releases/download/v1.7.15/containerd-1.7.15-linux-amd64.tar.gz
#TODO rsync -avz  /Users/zhouxujin/Downloads/containerd-1.7.15-linux-amd64.tar.gz root@113.44.50.184:/root
sudo tar Cxzvf /usr/local containerd-1.7.15-linux-amd64.tar.gz
#TODO curl -O https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
#TODO rsync -avz  /Users/zhouxujin/Downloads/containerd.service root@113.44.50.184:/root
sudo mv containerd.service /usr/lib/systemd/system/containerd.service
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

# 手动更新 containerd 中的 runc，以支持现代 Linux 功能
#TODO curl -Lo /Users/zhouxujin/Downloads/runc https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64
#TODO rsync -avz  /Users/zhouxujin/Downloads/runc root@113.44.50.184:/root
which runc
cp /usr/bin/runc /usr/bin/runc.bak
install -m 755 runc /usr/bin/runc
runc --version

# 安装 nerdctl（nerdctl 是 containerd 的官方兼容工具，提供类似 Docker 的 CLI 体验）
#TODO curl -L https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-1.7.6-linux-amd64.tar.gz -o /Users/zhouxujin/Downloads/nerdctl-1.7.6-linux-amd64.tar.gz
#TODO rsync -avz  /Users/zhouxujin/Downloads/nerdctl-1.7.6-linux-amd64.tar.gz root@113.44.50.184:/root
sudo tar Cxzvf /usr/local/bin nerdctl-1.7.6-linux-amd64.tar.gz
chmod +x /usr/local/bin/nerdctl
nerdctl --version

# 安装 buildkit （buildkit 是 containerd 的官方构建工具，提供类似 Docker Build 的功能）
# TODO curl -L https://github.com/moby/buildkit/releases/download/v0.12.5/buildkit-v0.12.5.linux-amd64.tar.gz -o /Users/zhouxujin/Downloads/buildkit-v0.12.5.linux-amd64.tar.gz
# TODO rsync -avz  /Users/zhouxujin/Downloads/buildkit-v0.12.5.linux-amd64.tar.gz root@113.44.50.184:/root
sudo tar Cxzvf /usr/local buildkit-v0.12.5.linux-amd64.tar.gz
chmod +x /usr/local/bin/buildctl
buildctl --version


# 查看 kubeadm 要用哪些镜像
kubeadm config images list --kubernetes-version v1.29.15

# 初始化 Kubernetes 主节点，如果执行 init 过慢（google 镜像源下载过慢），可以 push 到阿里云镜像仓库，从阿里云 pull 镜像到服务器，tag 镜像名称为 registry.k8s.io
# 使用 nerdctl 登录阿里云镜像仓库，如果显示：FATA[0000] /root/.docker/config.json: Invalid auth configuration file，说明和 docker 登录冲突，先删除凭据文件再用 nerdctl 登录：rm -f ~/.docker/config.json
#TODO registry.k8s.io/kube-apiserver:v1.29.15
#TODO registry.k8s.io/kube-controller-manager:v1.29.15
#TODO registry.k8s.io/kube-scheduler:v1.29.15
#TODO registry.k8s.io/kube-proxy:v1.29.15
#TODO registry.k8s.io/pause:3.8
#TODO registry.k8s.io/etcd:3.5.16-0
#TODO registry.k8s.io/coredns/coredns:v1.11.1
rm -f ~/.docker/config.json
echo "zxj201328" | nerdctl login --username=472493922@qq.com crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com --password-stdin
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-apiserver:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-controller-manager:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-scheduler:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-proxy:v1.29.15
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.8
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/etcd:3.5.16-0
nerdctl -n k8s.io pull crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/coredns:v1.11.1
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-apiserver:v1.29.15 registry.k8s.io/kube-apiserver:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-controller-manager:v1.29.15 registry.k8s.io/kube-controller-manager:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-scheduler:v1.29.15 registry.k8s.io/kube-scheduler:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/kube-proxy:v1.29.15 registry.k8s.io/kube-proxy:v1.29.15
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/pause:3.8 registry.k8s.io/pause:3.8
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/etcd:3.5.16-0 registry.k8s.io/etcd:3.5.16-0
nerdctl -n k8s.io tag crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/coredns:v1.11.1 registry.k8s.io/coredns/coredns:v1.11.1
nerdctl -n k8s.io images

sudo kubeadm init \
  --kubernetes-version v1.29.15 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU,Mem \
  -v=6

# 主节点执行以下命令，让 kubectl 正确指向 API Server。
export KUBECONFIG=/etc/kubernetes/admin.conf
# 从节点执行以下命令，让 kubectl 正确指向 API Server。
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 Flannel 网络插件
# TODO curl -Lo /Users/zhouxujin/Downloads/kube-flannel.yml https://raw.githubusercontent.com/flannel-io/flannel/v0.25.1/Documentation/kube-flannel.yml
# TODO rsync -avz  /Users/zhouxujin/Downloads/kube-flannel.yml root@113.44.50.184:/root
kubectl apply -f /root/kube-flannel.yml

# 彻底重新初始化
# 1. Reset 当前集群
sudo kubeadm reset -f
# 2. 可选：清理网络配置
sudo rm -rf /etc/cni/net.d
# 3. 可选：清理 etcd 数据（主节点用）
sudo rm -rf /var/lib/etcd
# 4. 可选：清理 kubeconfig
sudo rm -rf ~/.kube /etc/kubernetes
# 5. 重新 init
sudo kubeadm init \
  --kubernetes-version v1.29.15 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU,Mem \
  -v=6
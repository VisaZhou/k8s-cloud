#!/bin/bash
# ============================================================
# Kubernetes & Containerd 清理脚本（增强版）
# 功能：
# 1. 停止服务
# 2. 杀掉残留控制平面进程
# 3. 删除 kubeadm/kubelet/kubectl 和 containerd 相关文件
# 4. 清理残留容器、网络和 CNI 配置
# 5. 清理 iptables 和模块配置
# ============================================================

echo "开始清理 Kubernetes、containerd 和离线文件 ..."

BIN_PATH="/usr/local/bin"
SYS_BIN_PATH="/usr/bin"

# ===================== 停止服务 =====================
echo "停止 kubelet 和 containerd 服务 ..."
sudo systemctl stop kubelet containerd 2>/dev/null
sudo systemctl disable kubelet containerd 2>/dev/null

# ===================== 杀掉残留控制平面进程 =====================
echo "[INFO] 杀掉残留 Kubernetes 进程 ..."
K8S_PIDS=$(sudo lsof -ti:6443)
if [ -n "$K8S_PIDS" ]; then
    echo "[INFO] 检测到 kube-apiserver 占用 6443 端口，PID: $K8S_PIDS"
    for pid in $K8S_PIDS; do
        sudo kill -9 "$pid"
    done
    sleep 2
fi

# ===================== 清理残留容器 =====================
echo "[INFO] 删除残留容器..."
if command -v nerdctl &>/dev/null && [ -S /run/containerd/containerd.sock ]; then
    containers=$(sudo nerdctl -n k8s.io ps -aq)
    if [ -n "$containers" ]; then
        echo "[INFO] 删除 nerdctl 容器: $containers"
        sudo nerdctl -n k8s.io rm -f "$containers"
    else
        echo "[INFO] 没有残留 nerdctl 容器"
    fi
else
    echo "[INFO] nerdctl 未安装或 containerd 未运行，跳过"
fi


# ===================== kubeadm reset =====================
echo "重置 kubeadm ..."
sudo kubeadm reset -f 2>/dev/null

# ===================== 删除二进制文件 =====================
echo "删除 Kubernetes 二进制文件 ..."
sudo rm -f ${SYS_BIN_PATH}/kubeadm ${SYS_BIN_PATH}/kubectl ${SYS_BIN_PATH}/kubelet

echo "删除 containerd 相关二进制文件 ..."
sudo rm -f ${BIN_PATH}/nerdctl ${BIN_PATH}/crictl ${BIN_PATH}/buildctl ${BIN_PATH}/containerd* ${BIN_PATH}/runc


# ===================== 删除系统服务文件 =====================
echo "删除 systemd 服务文件 ..."
sudo rm -f /etc/systemd/system/kubelet.service
sudo rm -f /etc/systemd/system/containerd.service
sudo rm -f /etc/systemd/system/kubelet.d/10-kubeadm.conf

# 重新加载 systemd
sudo systemctl daemon-reload

# ===================== 删除 Kubernetes/Containerd 数据 =====================
echo "删除 Kubernetes 和 containerd 数据目录 ..."
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /var/lib/cni /opt/cni /etc/cni
sudo rm -rf /var/lib/containerd /etc/containerd

# ===================== 清理 iptables =====================
echo "清理 iptables ..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# ===================== 清理残留模块和配置 =====================
echo "清理系统模块和配置 ..."
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/sysctl.d/k8s.conf

# ===================== 检查端口 =====================
echo "[INFO] 检查 6443 端口占用 ..."
if sudo lsof -i :6443 &>/dev/null; then
    echo "[WARN] 端口 6443 仍被占用，请手动释放或重启服务器"
else
    echo "[INFO] 端口 6443 已释放"
fi

# ===================== 完成 =====================
echo "清理完成，服务器已恢复干净状态。"
# Kubernetes 集群部署指南（CentOS 8.2 公网访问节点）

本文档描述了在 CentOS 8.2 服务器上部署 Kubernetes 集群的步骤，包括主节点和工作节点初始化、节点加入集群等流程。


## 1. 前置要求

- 所有节点可通过公网互相访问
- 服务器操作系统为 **CentOS 8.2**
- 具有 root 权限或 sudo 权限
- 本地已配置代理（如需要下载 Kubernetes 组件或镜像）

---

## 2. 公网 IP 配置

在所有节点上临时添加公网 IP（主节点和工作节点都需执行）：

注意：此 IP 为临时生效，重启后失效。如需永久生效，请配置网络脚本或 NetworkManager。

### 主节点示例：
```bash
# 使用 root 用户执行
ip addr add <主节点公网IP>/32 dev eth0

# 验证 IP 是否生效
ip addr show eth0
```

### 工作节点示例：
```bash
# 使用 root 用户执行
ip addr add <工作节点公网IP>/32 dev eth0

# 验证 IP 是否生效
ip addr show eth0
```
---

## 3. 服务器初始化

### centos 8.2 服务器初始化
执行脚本 `/centos8-update/update-repo.sh`，更新系统仓库

执行脚本 `/centos8-update/vim-font-init.sh`，安装 vim 字体


### 主节点
本地先挂代理，执行 `/master-node/local-upload.sh` 脚本，下载并上传文件

上传初始化脚本到主节点服务器 `/master-node/remote-init.sh`

登录主节点服务器，执行 `/master-node/remote-init.sh` 脚本安装环境

`/master-node/remote-clean.sh` 为清理脚本


### 工作节点
本地先挂代理，执行 `/worker-node/local-upload.sh` 脚本，下载并上传文件

登录工作节点服务器，执行 `/worker-node/remote-init.sh` 脚本安装环境

`/master-node/remote-clean.sh` 为清理脚本

### 将工作节点加入主节点所初始化的集群中

登录主节点执行以下命令获取 token
```bash
kubeadm token create --print-join-command

# 输出
# kubeadm join 117.72.125.176:6443 --token 6456o0.2ucadutxp7fj6bq5 --discovery-token-ca-cert-hash sha256:fcffc33d0f7a2894e27a5c07f673bd39764b44e97cb14293e566d3e1294a927e
```

登录工作节点执行以下命令，用主节点中获取的 token 加入集群
```bash
sudo PATH=$PATH kubeadm join 117.72.125.176:6443 --token 6456o0.2ucadutxp7fj6bq5 --discovery-token-ca-cert-hash sha256:fcffc33d0f7a2894e27a5c07f673bd39764b44e97cb14293e566d3e1294a927e
```

验证工作节点是否加入成功
```bash
kubectl get nodes
```

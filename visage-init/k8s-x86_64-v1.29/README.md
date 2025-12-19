# Kubernetes 集群部署指南（CentOS 8.2 公网访问节点）

本文档描述了在 CentOS 8.2 服务器上部署 Kubernetes 集群的步骤，包括主节点和工作节点初始化、节点加入集群等流程。


## 1. 前置要求

- 由于轻量级云主机，所以所有节点通过公网互相访问
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

---

## 4. 将工作节点加入主节点所初始化的集群中

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

如果要将已经加入的工作节点去除出集群
登录主节点执行以下命令
```bash
# 查看节点名
kubectl get nodes
# 删除 Kubernetes 的注册信息，不会影响节点本身的 kubelet 配置。
kubectl delete node <节点名称>
```

---

## 5. 在 K8s 中拉私有镜像
创建了一个 regcred secret，里面保存了阿里云私有镜像仓库的登录信息。
```bash
kubectl config use-context kubernetes-admin@kubernetes
kubectl create secret docker-registry regcred \
  --docker-server=crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com \
  --docker-username=472493922@qq.com \
  --docker-password=zxj201328
```

values.yaml 里指定 imagePullSecretName，Helm 会把它挂载到 ServiceAccount 上。这样通过这个 ServiceAccount 创建的 Pod 就可以自动使用这个 secret 拉取私有镜像。
```yml
imagePullSecretName: regcred
```

---

## 6. 在k8s中搭建 NFS 服务器
京东轻量级服务器其实就是一台裸机，不像公有云那样有现成的云硬盘 CSI 插件，所以需要自己搭建 NFS 服务器

### 什么是NFS
- NFS 全称 Network File System
- 它的作用是：让多台电脑通过网络共享一个文件夹，就像本地磁盘一样使用。

### k8s 的 NFS 部署在哪里
- NFS 服务端跑在 Master 节点上。
- Worker 节点作为客户端，通过 IP 挂载 NFS。
- 所有 Pod 使用的卷，实际上都写在 Master 节点上的 /data/nfs。

### 如何部署 NFS
CentOS 系统的 Master 节点安装 NFS，并且启动 nfs-server 服务，作为 NFS 的服务端。
```bash
sudo yum install -y nfs-utils

sudo systemctl enable nfs-server --now
# Created symlink /etc/systemd/system/multi-user.target.wants/nfs-server.service → /usr/lib/systemd/system/nfs-server.service.
```

创建一个共享目录,并授予权限
```bash
sudo mkdir -p /data/nfs

sudo chmod 777 /data/nfs
```

配置导出目录
```bash
# 编辑文件
vim /etc/exports

# 写入
/data/nfs *(rw,sync,no_subtree_check,no_root_squash)

# 执行
sudo exportfs -rav
```

确认 NFS 服务是否正常
```bash
# 查看导出情况
sudo exportfs -v

# 检查 NFS 服务
sudo systemctl status nfs-server
```

在 Worker 节点也需要安装 NFS 但是不需要启动 nfs-server 服务
```bash
sudo yum install -y nfs-utils
```

Worker 节点挂载测试
- Worker 节点挂载实际上是都存储在了 Master 节点。
- 所以挂载完成后，在 Worker 节点的挂载目录新建文件，两边都能看到。取消挂载之后，Master 节点的该文件还存在，Worker 节点文件消失。
```bash
sudo mount -t nfs <master节点IP>:/data/nfs /mnt
```

Work 节点取消挂载的两种方式
```bash
# 退出当前挂载点
cd /

# 取消挂载的两种方式
sudo umount /mnt
sudo umount  <master节点IP>:/data/nfs
```

---

## 7. nfs-subdir-external-provisioner

### 什么是 nfs-subdir-external-provisioner
nfs-subdir-external-provisioner 是 Kubernetes 的一个 NFS 动态存储插件。
- 当用户申请 PVC 时，它会在 NFS 服务器上的指定目录下新建一个子目录。
- 它会把这个新建的子目录挂载成 PV，然后自动绑定到 PVC。

### 部署 nfs-subdir-external-provisioner
本地 kubectl 切到本地 minikube 环境挂代理下载 nfs-subdir-external-provisioner 到当前目录
```bash
kubectl config use-context minikube
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm pull nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --version 4.0.15 --untar
```
在拉取的 helm-chart 中修改镜像地址为私有镜像，并修改 imagePullSecrets
```yml
image:
  repository: crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/nfs-subdir-external-provisioner
  tag: v4.0.2
  pullPolicy: IfNotPresent
imagePullSecrets:
  - name: regcred
```
本地 kubectl 切到服务器 k8s 环境安装 nfs-subdir-external-provisioner，注意：helm 执行远程部署命令时，指定的 chart 地址为本地 mac 路径。
```bash
kubectl config use-context kubernetes-admin@kubernetes
helm install nfs-provisioner /Users/zhouxujin/Documents/zhouxujin/personal/k8s-cloud/init/k8s-x86_64-v1.29/nfs-subdir-external-provisioner \
  --set nfs.server=<NFS服务器IP> \
  --set nfs.path=/data/nfs
```

---

## 在K8s中配置 StorageClass

定义一个 StorageClass，并设置它为默认存储类，这样以后所有没有显式指定 storageClassName 的 PVC 都会用它。

| 参数                          | 作用                                                                                                                                                                                             |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| annotations:storageclass.kubernetes.io/is-default-class | Kubernetes 用来标记默认 StorageClass 的方式。<br>1. 当创建一个 PVC 没有指定 storageClassName 时，Kubernetes 会自动使用带有这个注解的 StorageClass 来动态创建 PV。<br>2. 集群只能有一个默认 StorageClass。                                       |
| provisioner                 | 指定存储插件，决定由谁来创建 PV。<br>1. 本地环境 Minikube：k8s.io/minikube-hostpath：只用于单机测试，因为 Pod 调度到别的节点会挂不了。<br>2. NFS：可以在服务器上搭一个 NFS 服务。<br>3. 云厂商：阿里云：diskplugin.csi.alibabacloud.com，AWS EBS：ebs.csi.aws.com |
| parameters.archiveOnDelete  | 当 PVC 被删除时，底层存储卷的数据是否保留到一个 archive 目录。<br>1. true： PVC 删除时，数据会移动到 archive 目录，保留备份。<br>2. false：PVC 删除时，数据直接删除，不保留。                                                                             |
| reclaimPolicy               | PVC 删除后，PV 的命运。<br>1. Retain：保留，数据不会丢，需要手动清理 PV/PVC。<br>2. Delete：PVC 删除时，PV 也自动删除，适合临时存储。                                                                                                     |
| volumeBindingMode           | 控制 PVC 什么时候绑定 PV。<br>1. Immediate：PVC 创建时立即绑定，默认值。<br>2. WaitForFirstConsumer：等 Pod 调度后再绑定。                                                                                                    |

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client 
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: cluster.local/nfs-provisioner-nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "true" 
reclaimPolicy: Delete
volumeBindingMode: Immediate
```
## 服务器安装 k8s 环境


### 主节点
本地先挂代理，执行 `/master-node/local-upload.sh` 脚本，下载并上传文件

登录主节点服务器，执行 `/master-node/remote-init.sh` 脚本安装环境

### 工作节点
本地先挂代理，执行 `/worker-node/local-upload.sh` 脚本，下载并上传文件

登录工作节点服务器，执行 `/worker-node/remote-init.sh` 脚本安装环境

### 将工作节点加入主节点所初始化的集群中

登录主节点执行以下命令获取 token
```bash
kubeadm token create --print-join-command

# 输出
# kubeadm join 192.168.0.66:6443 --token emy5v6.g4d2b217z6at8s8b --discovery-token-ca-cert-hash sha256:0fe1f29a9f25248260a09c60fe1cd10809cc3c1be80977aadea672cc8aae3547
```

登录工作节点执行以下命令，用主节点中获取的 token 加入集群
```bash
sudo kubeadm join 113.44.50.184:6443 --token emy5v6.g4d2b217z6at8s8b --discovery-token-ca-cert-hash sha256:0fe1f29a9f25248260a09c60fe1cd10809cc3c1be80977aadea672cc8aae3547
```

验证工作节点是否加入成功
```bash
kubectl get nodes
```
##  Jenkins Helm Chart 中常见的四个镜像的作用

| 镜像 | 作用                                                                                                         |
|---|------------------------------------------------------------------------------------------------------------|
| docker.io/jenkins/jenkins | Jenkins Controller 主服务镜像<br>1. 这是 Jenkins 的核心容器，运行 Web UI、插件、流水线调度、任务管理等所有核心功能。<br>2. 部署到 Kubernetes 里时，一般是 StatefulSet（jenkins-controller）。<br>3. 相当于 Jenkins 的“大脑”，负责调度和管理整个 CI/CD 平台。|
| docker.io/kiwigrid/k8s-sidecar:1.30.7  | ConfigMap/Secret 同步 Sidecar 容器<br>1. 用来监听 Kubernetes 的 ConfigMap/Secret 变化（通过 label 匹配），并把它们挂载到 Jenkins Pod 里。<br>2. 在 Jenkins Chart 里主要用来同步 JCasC 配置文件（Jenkins Configuration as Code）和 Job DSL 配置。<br>3. 好处是你只要改 ConfigMap，sidecar 就会把配置文件同步进去，Jenkins Controller 会自动加载。<br>4. 相当于一个“配置热加载器”。|
| jenkins/inbound-agent:3327.v868139a_d00e0-7 | Jenkins Agent 镜像（Kubernetes Pod 执行器）<br>1. Jenkins Controller 自己一般不跑任务（numExecutors=0），任务需要放到 Agent Pod 上跑。<br>2. 这个镜像就是 Jenkins 动态 Agent 的默认容器，运行 JNLP（Java Network Launch Protocol）客户端，负责和 Controller 建立连接。<br>3. 一旦有任务，Controller 会创建一个 inbound-agent Pod，把构建步骤交给它执行，任务跑完 Pod 就销毁。<br>4. 相当于 Jenkins 的“工人”。 |
| docker.io/bats/bats:1.12.0 | Helm Chart 测试用镜像<br>1. BATS（Bash Automated Testing System）是一个 Bash 脚本测试框架。<br>2. 在 Jenkins Chart 里，它不是 Jenkins 必需的运行组件，而是用于 helm test hooks。<br>3. Chart 部署完成后，会临时拉起一个带 BATS 的 Pod，跑一些测试脚本，验证 Jenkins 是否正常启动（例如检查 Web UI 200 状态）。<br>4. 测试结束 Pod 会销毁。<br>5. 相当于“验收员”，确保部署的 Jenkins 是健康的。  |

## values.yaml 里需修改的关键配置
```yml
controller:
  image:
    registry: "crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com"
    repository: "visage-namespace/jenkins"
    tag: "lts"

  imagePullSecretName: regcred

  resources:
    requests:
      cpu: "50m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "2Gi"

  javaOpts: "-Xms1024m -Xmx2048m"

  probes:
    startupProbe:
      failureThreshold: 120

persistence:
  enabled: true
  storageClass: nfs-client
  accessMode: "ReadWriteOnce"
  size: "16Gi"
```

## 常见问题
### 组合状态 Init:1/2 是什么意思？
1. 以下表示 Pod 里面一共有 2 个容器（2/2），但当前 0 个容器是 Ready 状态（0/2）。
2. Init:1/2 表示有一个 Init 容器还没完成初始化（Init 容器是主容器启动前运行的特殊容器，通常用来做一些准备工作）。
3. 如果要查看 Init 容器的日志，可以用以下命令：`kubectl logs helm-jenkins-0 -c init`
```bash
NAME                                                              READY   STATUS     RESTARTS      AGE
helm-jenkins-0                                                    0/2     Init:1/2   0             45s
```

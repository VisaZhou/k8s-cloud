## values.yaml 里需修改的关键配置

### 镜像
```yml
image:
  registry: "crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com"
  repository: "visage-namespace/traefik"
  tag: "3.0"
  pullPolicy: IfNotPresent
```

### Secret
```yml
deployment:
  # 拉取镜像的 Secret
  imagePullSecrets:
    - name: regcred
```

### 端口
| 端口类型                                      | 容器内端口                                             | k8s Service 集群内部端口                                                | NodePort端口：集群外访问，范围 30000 – 32767                            |
|-------------------------------------------|---------------------------------------------------|-------------------------------------------------------------------|--------------------------------------------------------------|
| Dashboard 端口         | port：8080                                         | 不需要暴露，靠流量入口转发                                                     |                                                              |
| 流量入口/HTTP      | port：8000（dashboard，jenkins）<br/>port：8001（nexus） | exposedPort：30000（dashboard，jenkins）<br/>exposedPort：30001（nexus） | nodePort：30000 （dashboard，jenkins）<br/>nodePort：30001（nexus） |
| 流量入口/HTTPS（暂不需要） | port：443                                          |                                                                   |                                                              |
| Prometheus 指标（暂不需要）  | port：9100                                         |                                                                   |                                                              |

只需要修改流量入口，其他配置不变：
```yml
ports:
  # 流量入口
  web:
    # 容器内端口
    port: 8000
    # 暴露到 k8s Service 的端口:30000
    expose:
      default: true
    exposedPort: 30000
    protocol: TCP
    # 把 k8s Service 的端口:30000 暴露到宿主机的端口:30000
    # 注意：NodePort端口的范围为：30000 – 32767
    nodePort: 30000
    
  # 流量入口（nexus，因为nexus不支持路径匹配，必须是根路径，所以新开一个端口）
  web-nexus:
    # 容器内端口
    port: 8001
    expose:
      default: true
    exposedPort: 30001
    protocol: TCP
    nodePort: 30001

  tcp-mysql:
    port: 3306
    expose:
      default: true
    exposedPort: 30306
    targetPort:
    protocol: TCP
    nodePort: 30306
    
  web-nacos:
    port: 8848
    expose:
      default: true
    exposedPort: 30002
    targetPort:
    protocol: TCP
    nodePort: 30002
```

### service
```yml
# 定义类型为：NodePort
service:
  enabled: true
  type: NodePort
```

### IngressRoute
```yml
ingressRoute:
  # 路由匹配 Dashboard
  dashboard:
    enabled: true
    annotations: {}
    labels: {}
    # 当请求路径以 /dashboard 或 /api 开头时，这条路由生效
    matchRule: PathPrefix(`/dashboard`) || PathPrefix(`/api`)
    # 指定流量要转发到的服务
    services:
      - name: api@internal
        kind: TraefikService
    # 指定流量入口
    entryPoints: ["web"]
    middlewares: []
    tls: {}
```


### 挂载
使用证书时才需要挂载pvc，此处不需要配置,保持原样
```yml
persistence:
  enabled: false
  name: data
  existingClaim: ""
  accessMode: ReadWriteOnce
  size: 128Mi
  storageClass: ""
  volumeName: ""
  path: /data
  annotations: {}
  subPath: ""
```


### 访问
使用主节点IP + NodePort端口访问
```bash
http://117.72.125.176:30000/dashboard/
```
使用子节点IP + NodePort端口访问
```bash
http://117.72.153.178:30000/dashboard/
```
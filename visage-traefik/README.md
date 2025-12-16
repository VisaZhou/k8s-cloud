## values.yaml 里需修改的关键配置

### 镜像
```yml
image:
  registry: "crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com"
  repository: "visage-namespace/traefik:3.0"
  tag:
  pullPolicy: IfNotPresent
```

### Secret
```yml
# 拉取镜像的 Secret
imagePullSecrets:
  - name: regcred
```

### 端口


| 端口类型                                      | 容器内端口 | k8s Service 暴露的端口 | 互联网访问端口  |
|-------------------------------------------|-------|-------------------|---|
| Dashboard 端口         |port：8080       | 不需要暴露，靠流量入口转发     |   |
| 流量入口/HTTP      | port：80      | exposedPort：28000                  | nodePort：28000  |
| 流量入口/HTTPS（暂不需要） | port：443      |                   |   |
| Prometheus 指标（暂不需要）  | port：9100      |                   |   |

只需要修改流量入口，其他配置不变：
```yml
ports:
  web:
    port: 8000
    expose:
      default: true
    exposedPort: 28000
    protocol: TCP
    nodePort: 28000
```

### service
定义类型为：NodePort
```yml
service:
  enabled: true
  type: NodePort
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
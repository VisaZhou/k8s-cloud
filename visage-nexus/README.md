## values.yaml 里需修改的关键配置
```yml
image:
  repository: crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/nexus3
  tag: latest
  digest:
  pullPolicy: IfNotPresent

bashImage:
  repository: crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/bash
  tag: latest
  digest:
  pullPolicy: IfNotPresent

jdkImage:
  repository: crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com/visage-namespace/eclipse-temurin
  tag: 21-jdk
  digest:
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: regcred

persistence:
  enabled: true
  annotations: {}
  accessMode: ReadWriteOnce
  storageClass: nfs-client
  size: 30Gi
  retainDeleted: true
  retainScaled: true
```

## 启动 nexus 和 IngressRoute
```bash
# 启动 nexus
helm upgrade --install nexus3 ./nexus3
# 启动 IngressRoute
kubectl apply -f nexus-ingressroute.yaml
```

配置完 IngressRoute 后，访问 nexus 地址及密码
```txt
- 地址：http://117.72.125.176:30001/
- 用户名：admin
- 初始密码：zxj201328
- 初始密码查看：kubectl exec -it nexus3-0 -- cat /nexus-data/admin.password
```
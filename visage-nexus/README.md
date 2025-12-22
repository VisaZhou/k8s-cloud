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

## 批量上传 jar 脚本
查看本地idea 内置 maven 路径
```bash
/Applications/IntelliJ\ IDEA.app/Contents/plugins/maven/lib/maven3/bin/mvn -v

# 显示
# Apache Maven 3.9.9 (8e8579a9e76f7d015ee5ec7bfcdc97d260186937)
# Maven home: /Applications/IntelliJ IDEA.app/Contents/plugins/maven/lib/maven3
# Java version: 23.0.1, vendor: Oracle Corporation, runtime: /Users/zhouxujin/Library/Java/JavaVirtualMachines/openjdk-23.0.1/Contents/Home
# Default locale: zh_CN_#Hans, platform encoding: UTF-8
# OS name: "mac os x", version: "14.4.1", arch: "aarch64", family: "mac"
```

创建 settings.文件
```xml
<?xml version="1.0" encoding="UTF-8"?>

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">

  <servers>
	<server> 
      <id>nexus</id>
      <username>admin</username>
      <password>zxj201328</password>
    </server>
  </servers>
    
<localRepository>/Users/zhouxujin/Documents/zhouxujin/mavenRepository</localRepository>
    
<mirrors>
  <mirror>
    <id>maven-public</id>
    <name>visage maven central</name>
    <url>http://117.72.125.176:30001/repository/maven-public/</url>
    <mirrorOf>external:*</mirrorOf>
  </mirror>
</mirrors>

</settings>
```

batchUpload.sh 脚本
```bash
#!/bin/bash

# ========= Nexus 仓库地址 =========
RELEASE_REPO_URL="http://117.72.125.176:30001/repository/maven-releases/"
SNAPSHOT_REPO_URL="http://117.72.125.176:30001/repository/maven-snapshots/"

REPO_ID="nexus"

# ========= 本地 Maven =========
LOCAL_MAVEN="/Applications/IntelliJ IDEA.app/Contents/plugins/maven/lib/maven3/bin/mvn"
LOCAL_SETTINGS="/Users/zhouxujin/Documents/zhouxujin/mavenRepository/visage-settings.xml"

# ========= 本地 Maven 仓库 =========
LOCAL_REPO="/Users/zhouxujin/Documents/zhouxujin/mavenRepository"

# ========= 临时目录 =========
TMP_DIR="/tmp/maven-upload"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "====== Maven 批量上传开始 ======"

find "$LOCAL_REPO" -name "*.jar" | while read jar; do
  pom="${jar%.jar}.pom"

  # 没有 pom 直接跳过
  [ ! -f "$pom" ] && continue

  jar_name=$(basename "$jar")
  pom_name=$(basename "$pom")

  # ===== 判断 SNAPSHOT / RELEASE =====
  if [[ "$jar_name" == *"-SNAPSHOT.jar" ]]; then
    TARGET_REPO_URL="$SNAPSHOT_REPO_URL"
    TARGET_TYPE="SNAPSHOT"
  else
    TARGET_REPO_URL="$RELEASE_REPO_URL"
    TARGET_TYPE="RELEASE"
  fi

  # ===== 复制到非本地仓库路径 =====
  cp "$jar" "$TMP_DIR/$jar_name"
  cp "$pom" "$TMP_DIR/$pom_name"

  echo ">>> [$TARGET_TYPE] Deploying $jar_name"

  "$LOCAL_MAVEN" deploy:deploy-file \
    -s "$LOCAL_SETTINGS" \
    -DrepositoryId="$REPO_ID" \
    -Durl="$TARGET_REPO_URL" \
    -Dfile="$TMP_DIR/$jar_name" \
    -DpomFile="$TMP_DIR/$pom_name" \
    -DgeneratePom=false \
    -DretryFailedDeploymentCount=2 \
    -Dhttp.connectionTimeout=60000 \
    -Dhttp.readTimeout=600000

done

echo "====== Maven 批量上传完成 ======"

# 清理临时目录
rm -rf "$TMP_DIR"
```
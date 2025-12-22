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
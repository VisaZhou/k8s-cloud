# 当脚本中的任一命令返回非零退出状态时立即终止执行。
set -e
# 在执行命令前打印命令及其参数，方便调试。
set -x

# 从.env文件中读取环境变量,只能在shell脚本中使用，不会自动传递到 docker build
source .env

echo " 开始登录私有镜像仓库..."
echo "$REPOSITORY_PASSWORD" | docker login --username="$REPOSITORY_USERNAME" "$REPOSITORY_URL" --password-stdin

echo " 开始执行 jenkins 远程部署..."
helm upgrade --install helm-jenkins ./helm-jenkins

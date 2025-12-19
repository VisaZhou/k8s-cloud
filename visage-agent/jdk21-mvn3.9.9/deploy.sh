# 当脚本中的任一命令返回非零退出状态时立即终止执行。
set -e
# 在执行命令前打印命令及其参数，方便调试。
set -x

repo_password="zxj201328"
repo_username="472493922@qq.com"
repo_url="crpi-iay62pbhw1a58p10.cn-hangzhou.personal.cr.aliyuncs.com"
repo_namespace="visage-build"
image_name="jdk-mvn-agent"
image_version="21-3.9.9"

echo " 开始登录私有镜像仓库..."
echo "$repo_password" | docker login --username="$repo_username" "$repo_url" --password-stdin

echo " 开始构建 Jenkins 客户端镜像..."
docker build -t "$image_name:$image_version" -f Dockerfile .

# 上传前需要先打tag，将本地镜像标记为阿里云镜像仓库地址
docker tag "$image_name:$image_version" "$repo_url/$repo_namespace/$image_name:$image_version"

# 上传镜像到阿里云的镜像仓库
docker push "$repo_url/$repo_namespace/$image_name:$image_version"

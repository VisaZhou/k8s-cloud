#!/bin/bash

# ============================================================
# 脚本功能：
#   1. 备份系统中所有现有的 yum/dnf 仓库配置文件到 backup 目录
#   2. 清理旧仓库配置，避免重复或失效源导致的 404 错误
#   3. 添加 CentOS 8 Vault 仓库（BaseOS、AppStream、Extras）
#      - 解决 CentOS 8 官方镜像已 EOL 导致的软件包无法下载问题
#   4. 清理 dnf 缓存并生成新仓库元数据，确保可以正常安装软件包
#
# 适用场景：
#   - CentOS 8 系统已经停止官方维护，旧仓库不可用
#   - 安装软件包（如 vim、curl 等）报 404 或找不到元数据
#   - 避免仓库重复配置导致的警告
# ============================================================

# ===================== 备份旧仓库并清空 =====================
sudo mkdir -p /etc/yum.repos.d/backup
sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/

# ===================== 添加 CentOS Vault 仓库 =====================
sudo tee /etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
[BaseOS]
name=CentOS-8.5 - Base
baseurl=http://vault.centos.org/8.5.2111/BaseOS/x86_64/os/
enabled=1
gpgcheck=0

[AppStream]
name=CentOS-8.5 - AppStream
baseurl=http://vault.centos.org/8.5.2111/AppStream/x86_64/os/
enabled=1
gpgcheck=0

[extras]
name=CentOS-8.5 - Extras
baseurl=http://vault.centos.org/8.5.2111/extras/x86_64/os/
enabled=1
gpgcheck=0
EOF

# ===================== 清理缓存 =====================
sudo dnf clean all
sudo dnf makecache

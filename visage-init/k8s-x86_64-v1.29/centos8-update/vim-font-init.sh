#!/bin/bash

# ============================================================
# 脚本功能：
#   1. 设置 Vim 永久使用 UTF-8 编码
#   2. 配置终端显示 UTF-8
#   3. 安装常用字体，保证中文显示
# ============================================================

# ===================== 设置系统语言为中文 =====================
sudo localectl set-locale LANG=zh_CN.UTF-8
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# ===================== 安装 vim =====================
sudo dnf install -y vim

# ===================== 安装常用中文/Unicode 字体 =====================
sudo dnf install -y dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts

# ===================== 配置 Vim 永久使用 UTF-8 =====================
# 创建或修改 root 用户的 .vimrc
VIMRC_PATH="/root/.vimrc"
if [ ! -f "$VIMRC_PATH" ]; then
    touch "$VIMRC_PATH"
fi
cat > "$VIMRC_PATH" <<'EOF'
set encoding=utf-8
set fileencoding=utf-8
set termencoding=utf-8
set fileformats=unix,dos
EOF
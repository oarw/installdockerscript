#!/usr/bin/env bash
set -euo pipefail

#
# Install Docker Engine on Alpine Linux using Alpine's community repository.
# Docs: https://wiki.alpinelinux.org/wiki/Docker
#
# Usage:
#   sudo bash install-docker-alpine.sh
#
# Options:
#   --hello-world         Run "docker run hello-world" after install (default: skip)
#   --skip-hello-world    Skip running "docker run hello-world" after install (default)
#   --no-group            Skip adding the current user to the "docker" group
#   --help                Show help
#

SKIP_HELLO_WORLD=1
NO_GROUP=0

usage() {
  cat <<'EOF'
自动安装 Docker Engine（Alpine Linux / apk 仓库方式）

用法：
  sudo bash install-docker-alpine.sh [--hello-world] [--no-group]

选项：
  --hello-world         安装后运行 hello-world 验证（默认跳过）
  --skip-hello-world    跳过 hello-world 验证（默认）
  --no-group            不把当前用户加入 docker 组
  --help                显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hello-world) SKIP_HELLO_WORLD=0; shift ;;
    --skip-hello-world) SKIP_HELLO_WORLD=1; shift ;;
    --no-group) NO_GROUP=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "请使用 root 权限运行：sudo bash install-docker-alpine.sh" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "无法读取 /etc/os-release，无法确认系统发行版。" >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" != "alpine" ]]; then
  echo "检测到 ID=${ID:-unknown}。本脚本仅面向 Alpine Linux。" >&2
  exit 1
fi

echo "Alpine Linux 版本: ${VERSION_ID:-unknown}"

# 检查并启用 community 仓库（如果尚未启用）
COMMUNITY_ENABLED=0
if grep -q "^[^#]*@.*community" /etc/apk/repositories || grep -q "^[^#]*community" /etc/apk/repositories; then
  echo "检测到 community 仓库已启用。"
  COMMUNITY_ENABLED=1
else
  echo "检测到 community 仓库未启用，正在启用..."
  sed -i '/^#.*community/s/^#//' /etc/apk/repositories || {
    echo "警告：无法自动启用 community 仓库。请手动编辑 /etc/apk/repositories 并取消注释 community 行。" >&2
    echo "然后重新运行此脚本。" >&2
    exit 1
  }
  COMMUNITY_ENABLED=1
fi

echo "1) 更新包索引..."
apk update

echo "2) 卸载可能冲突的旧包（如果存在）..."
# Alpine 通常不会有这些冲突包，但为了安全起见还是检查一下
apk del docker docker-compose docker-cli containerd runc || true

echo "3) 安装 Docker Engine..."
apk add docker docker-cli-compose

echo "4) 启动并设置 Docker 服务开机自启..."
# Alpine 使用 OpenRC
if command -v rc-update >/dev/null 2>&1; then
  rc-update add docker default
  service docker start
elif command -v systemctl >/dev/null 2>&1; then
  # 万一 Alpine 使用了 systemd（不常见）
  systemctl enable --now docker
else
  echo "未检测到 rc-update 或 systemctl，跳过服务管理（请手动启动 Docker daemon）。" >&2
  echo "手动启动命令：service docker start" >&2
fi

if [[ "$NO_GROUP" -eq 0 ]]; then
  INVOKING_USER="${SUDO_USER:-}"
  if [[ -n "$INVOKING_USER" && "$INVOKING_USER" != "root" ]]; then
    echo "5) 将用户加入 docker 组：$INVOKING_USER"
    addgroup -S docker 2>/dev/null || true
    addgroup "$INVOKING_USER" docker || true
    echo "提示：需要重新登录/重启 shell 才能免 sudo 使用 docker。"
  else
    echo "5) 未检测到 SUDO_USER，跳过加入 docker 组。"
  fi
else
  echo "5) 跳过加入 docker 组（按 --no-group）。"
fi

echo "6) 验证版本："
docker --version || true
docker compose version || true

if [[ "$SKIP_HELLO_WORLD" -eq 0 ]]; then
  echo "7) 运行 hello-world 验证（可能会拉取镜像）..."
  docker run --rm hello-world
else
  echo "7) 跳过 hello-world（按 --skip-hello-world）。"
fi

echo "完成。"
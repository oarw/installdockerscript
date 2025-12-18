#!/usr/bin/env bash
set -euo pipefail

#
# Install Docker Engine on Debian using Docker's official apt repository.
# Docs: https://docs.docker.com/engine/install/debian/
#
# Usage:
#   sudo bash install-docker-debian.sh
#
# Options:
#   --skip-hello-world    Skip running "docker run hello-world" after install
#   --no-group            Skip adding the current user to the "docker" group
#   --help                Show help
#

SKIP_HELLO_WORLD=0
NO_GROUP=0

usage() {
  cat <<'EOF'
自动安装 Docker Engine（Debian / apt 仓库方式）

用法：
  sudo bash install-docker-debian.sh [--skip-hello-world] [--no-group]

选项：
  --skip-hello-world    安装后不运行 hello-world 验证
  --no-group            不把当前用户加入 docker 组
  --help                显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-hello-world) SKIP_HELLO_WORLD=1; shift ;;
    --no-group) NO_GROUP=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "请使用 root 权限运行：sudo bash install-docker-debian.sh" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "无法读取 /etc/os-release，无法确认系统发行版。" >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" != "debian" ]]; then
  echo "检测到 ID=${ID:-unknown}。本脚本仅面向 Debian（非 Ubuntu）。" >&2
  exit 1
fi

CODENAME="${VERSION_CODENAME:-}"
if [[ -z "$CODENAME" ]]; then
  echo "无法从 /etc/os-release 解析 VERSION_CODENAME（Debian codename）。" >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"

echo "Debian codename: $CODENAME"
echo "Architecture:    $ARCH"

echo "1) 卸载可能冲突的旧包（如果存在）..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc || true

echo "2) 安装依赖（ca-certificates, curl）..."
apt-get install -y ca-certificates curl

echo "3) 配置 Docker 官方 GPG keyring..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "4) 配置 Docker apt 仓库（deb822: /etc/apt/sources.list.d/docker.sources）..."
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "5) 安装 Docker Engine + Compose 插件..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "6) 启动并设置 Docker 服务开机自启..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now docker
else
  echo "未检测到 systemctl，跳过服务管理（请手动启动 Docker daemon）。" >&2
fi

if [[ "$NO_GROUP" -eq 0 ]]; then
  # Best-effort: add invoking user to docker group (works when invoked via sudo).
  INVOKING_USER="${SUDO_USER:-}"
  if [[ -n "$INVOKING_USER" && "$INVOKING_USER" != "root" ]]; then
    echo "7) 将用户加入 docker 组：$INVOKING_USER"
    groupadd -f docker || true
    usermod -aG docker "$INVOKING_USER" || true
    echo "提示：需要重新登录/重启 shell 才能免 sudo 使用 docker。"
  else
    echo "7) 未检测到 SUDO_USER，跳过加入 docker 组。"
  fi
else
  echo "7) 跳过加入 docker 组（按 --no-group）。"
fi

echo "8) 验证版本："
docker --version || true
docker compose version || true

if [[ "$SKIP_HELLO_WORLD" -eq 0 ]]; then
  echo "9) 运行 hello-world 验证（可能会拉取镜像）..."
  docker run --rm hello-world
else
  echo "9) 跳过 hello-world（按 --skip-hello-world）。"
fi

echo "完成。"



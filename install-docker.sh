#!/usr/bin/env bash
set -euo pipefail

#
# Auto-detect Debian/Ubuntu and install Docker Engine using Docker's official apt repository.
# Docs:
# - Debian: https://docs.docker.com/engine/install/debian/
# - Ubuntu: https://docs.docker.com/engine/install/ubuntu/
#
# Usage:
#   sudo bash install-docker.sh
#
# Options:
#   --skip-hello-world        Skip running "docker run hello-world" after install
#   --no-group                Skip adding the current user to the "docker" group
#   --codename <name>         Override distro codename used in docker.sources (useful for derivatives)
#   --help                    Show help
#

SKIP_HELLO_WORLD=0
NO_GROUP=0
CODENAME_OVERRIDE=""

usage() {
  cat <<'EOF'
自动安装 Docker Engine（自动识别 Debian / Ubuntu，使用官方 apt 仓库）

用法：
  sudo bash install-docker.sh [--skip-hello-world] [--no-group] [--codename <name>]

选项：
  --skip-hello-world        安装后不运行 hello-world 验证
  --no-group                不把当前用户加入 docker 组
  --codename <name>         覆盖系统 codename（衍生发行版可能需要）
  --help                    显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-hello-world) SKIP_HELLO_WORLD=1; shift ;;
    --no-group) NO_GROUP=1; shift ;;
    --codename)
      CODENAME_OVERRIDE="${2:-}"
      if [[ -z "$CODENAME_OVERRIDE" ]]; then
        echo "--codename 需要一个参数，例如：--codename bookworm" >&2
        exit 2
      fi
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "请使用 root 权限运行：sudo bash install-docker.sh" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "无法读取 /etc/os-release，无法确认系统发行版。" >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

DISTRO="${ID:-}"
case "$DISTRO" in
  ubuntu|debian) ;;
  *)
    echo "检测到 ID=${DISTRO:-unknown}，当前脚本仅自动支持 Debian/Ubuntu。" >&2
    echo "你也可以使用 --codename 指定对应发行版代号（仅在你明确知道应该用哪个代号时）。" >&2
    exit 1
    ;;
esac

BASE_URL="https://download.docker.com/linux/${DISTRO}"
GPG_URL="${BASE_URL}/gpg"

CODENAME=""
if [[ -n "$CODENAME_OVERRIDE" ]]; then
  CODENAME="$CODENAME_OVERRIDE"
else
  if [[ "$DISTRO" == "ubuntu" ]]; then
    # Ubuntu docs: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
    CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  else
    # Debian docs: $VERSION_CODENAME (derivatives may need override)
    CODENAME="${VERSION_CODENAME:-}"
  fi
fi

if [[ -z "$CODENAME" ]]; then
  echo "无法确定系统 codename（Ubuntu: UBUNTU_CODENAME/VERSION_CODENAME，Debian: VERSION_CODENAME）。" >&2
  echo "你可以尝试：sudo bash install-docker.sh --codename <name>" >&2
  exit 1
fi

echo "Distro:    $DISTRO"
echo "Codename:  $CODENAME"
echo "Repo:      $BASE_URL"

export DEBIAN_FRONTEND=noninteractive

echo "1) 卸载可能冲突的旧包（如果存在）..."
apt-get update
apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc || true

echo "2) 安装依赖（ca-certificates, curl）..."
apt-get install -y ca-certificates curl

echo "3) 配置 Docker 官方 GPG keyring..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "$GPG_URL" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "4) 配置 Docker apt 仓库（deb822: /etc/apt/sources.list.d/docker.sources）..."
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: ${BASE_URL}
Suites: ${CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "5) 安装 Docker Engine + Compose 插件..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "6) 启动并设置 Docker 服务开机自启..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now docker
else
  echo "未检测到 systemctl，跳过服务管理（请手动启动 Docker daemon）。" >&2
fi

if [[ "$NO_GROUP" -eq 0 ]]; then
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



## installdockerscript

基于 Docker 官方文档（apt 仓库方式）封装的**自动安装脚本**：

- Debian：[`https://docs.docker.com/engine/install/debian/`](https://docs.docker.com/engine/install/debian/)
- Ubuntu：[`https://docs.docker.com/engine/install/ubuntu/`](https://docs.docker.com/engine/install/ubuntu/)

### 适用范围

- **系统**：Debian / Ubuntu
- **安装方式**：Docker 官方 apt 仓库（`docker.sources` / keyring）
- **Compose**：安装 `docker-compose-plugin`，使用命令是 **`docker compose`**（注意中间有空格）

### 使用方法

1) 下载/拷贝脚本到机器后赋权：

```bash
chmod +x install-docker-debian.sh install-docker-ubuntu.sh
```

2) 以 root 权限运行：

- Debian：

```bash
sudo bash install-docker-debian.sh
```

- Ubuntu：

```bash
sudo bash install-docker-ubuntu.sh
```

### 常用选项

- **跳过 hello-world 验证**：

```bash
sudo bash install-docker-debian.sh --skip-hello-world
sudo bash install-docker-ubuntu.sh --skip-hello-world
```

- **不自动把当前用户加入 docker 组**：

```bash
sudo bash install-docker-debian.sh --no-group
sudo bash install-docker-ubuntu.sh --no-group
```

### 安装后验证

```bash
docker --version
docker compose version
```

> 如果你希望普通用户免 `sudo` 使用 docker：脚本会尽力把 `SUDO_USER` 加入 `docker` 组；通常需要重新登录（或重启会话）才生效。



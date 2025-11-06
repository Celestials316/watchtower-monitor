# 安装指南

本文档提供详细的安装步骤、多服务器配置和故障排查方法。

## 📋 目录

- [前置要求](#前置要求)
- [单服务器部署](#单服务器部署)
- [多服务器部署](#多服务器部署)
- [获取 Telegram 凭证](#获取-telegram-凭证)
- [验证安装](#验证安装)
- [故障排查](#故障排查)

---

## 前置要求

### 系统要求

- **操作系统**: Linux (Ubuntu 20.04+, Debian 11+, CentOS 8+)
- **架构**: amd64, arm64, arm/v7
- **内存**: 最低 512MB
- **磁盘**: 最低 100MB

### 软件要求

```bash
# 检查 Docker 版本（需要 20.10+）
docker --version

# 如果未安装
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 检查 Docker Compose（需要 v2.0+）
docker compose version

# 如果未安装
sudo apt-get install docker-compose-plugin
```

---

## 单服务器部署

### 步骤 1: 创建工作目录

```bash
mkdir -p ~/watchtower && cd ~/watchtower
```

### 步骤 2: 下载配置文件

```bash
# 下载 docker-compose.yml
curl -o docker-compose.yml https://raw.githubusercontent.com/Celestials316/watchtower-telegram-monitor/main/docker/docker-compose.yml
```

或手动创建 `docker-compose.yml`：

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    environment:
      - WATCHTOWER_NO_STARTUP_MESSAGE=true
      - TZ=Asia/Shanghai
      - WATCHTOWER_CLEANUP=${CLEANUP:-true}
      - WATCHTOWER_POLL_INTERVAL=${POLL_INTERVAL:-3600}
    labels:
      - "com.centurylinklabs.watchtower.enable=false"

  watchtower-notifier:
    image: w254992/watchtower-telegram-monitor:latest
    container_name: watchtower-notifier
    restart: unless-stopped
    network_mode: host
    depends_on:
      - watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data:/data
    env_file:
      - .env
    environment:
      - TZ=Asia/Shanghai
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

### 步骤 3: 创建环境变量文件

```bash
cat > .env << 'EOF'
# Telegram 配置（必填）
BOT_TOKEN=你的_bot_token
CHAT_ID=你的_chat_id

# 服务器名称（可选）
SERVER_NAME=我的服务器

# 检查间隔（秒）
POLL_INTERVAL=3600

# 自动清理旧镜像
CLEANUP=true

# 启用自动回滚
ENABLE_ROLLBACK=true
EOF

# 编辑配置
nano .env
```

**保存方式**: `Ctrl+O` → `Enter` → `Ctrl+X`

### 步骤 4: 启动服务

```bash
# 创建数据目录
mkdir -p data

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f
```

### 步骤 5: 验证

启动后 10-30 秒内应该收到 Telegram 启动通知。

```bash
# 检查状态
docker compose ps

# 查看日志
docker compose logs watchtower-notifier | tail -20
```

---

## 多服务器部署

多服务器需要共享数据以实现统一管理。支持两种方案：

### 方案一：Tailscale 虚拟局域网（强烈推荐）

**优点：**
- ✅ 配置简单（5分钟搞定）
- ✅ 安全加密
- ✅ 无需配置防火墙
- ✅ 跨公网内网都可用
- ✅ 免费（个人使用）

#### 第一步：安装 Tailscale

**在所有服务器上执行（京东云、云服务V2、云服务器V4）：**

```bash
# 1. 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. 启动并登录（会输出一个链接）
sudo tailscale up

# 3. 浏览器打开链接，使用 Google/GitHub/Microsoft 账号登录授权

# 4. 查看分配的 IP
tailscale ip -4
```

**记录每台服务器的 Tailscale IP：**

```bash
# 京东云
tailscale ip -4
# 输出示例: 100.64.1.10

# 云服务V2
tailscale ip -4
# 输出示例: 100.64.1.20

# 云服务器V4
tailscale ip -4
# 输出示例: 100.64.1.30
```

#### 第二步：配置 NFS 服务器

**选择一台服务器作为 NFS 主机（推荐京东云）：**

```bash
# SSH 登录京东云
ssh user@京东云IP

# 1. 安装 NFS 服务端
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# 2. 创建共享目录
sudo mkdir -p /srv/watchtower-shared
sudo chmod 777 /srv/watchtower-shared

# 3. 配置 NFS 导出
sudo nano /etc/exports
```

**在 `/etc/exports` 中添加（使用 Tailscale 内网 IP）：**

```
/srv/watchtower-shared 100.64.1.20(rw,sync,no_subtree_check,no_root_squash)
/srv/watchtower-shared 100.64.1.30(rw,sync,no_subtree_check,no_root_squash)
/srv/watchtower-shared 127.0.0.1(rw,sync,no_subtree_check,no_root_squash)
```

或者允许所有 Tailscale 网段（更方便）：

```
/srv/watchtower-shared 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash)
```

```bash
# 4. 应用配置
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

# 5. 验证 NFS
sudo systemctl status nfs-kernel-server
showmount -e localhost
```

#### 第三步：安装 NFS 客户端

**在所有服务器上（包括 NFS 主机）：**

```bash
sudo apt-get install -y nfs-common
```

#### 第四步：测试 NFS 连接

**在其他服务器（云服务V2、云服务器V4）上测试：**

```bash
# 测试能否看到共享
showmount -e 100.64.1.10  # 京东云的 Tailscale IP

# 应该显示：
# Export list for 100.64.1.10:
# /srv/watchtower-shared ...

# 测试挂载
sudo mkdir -p /mnt/test
sudo mount -t nfs 100.64.1.10:/srv/watchtower-shared /mnt/test
ls -la /mnt/test
sudo touch /mnt/test/test.txt
ls /mnt/test
sudo umount /mnt/test
```

#### 第五步：配置 Docker Compose

**京东云（NFS 主机）的 `docker-compose.yml`：**

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    environment:
      - WATCHTOWER_NO_STARTUP_MESSAGE=true
      - TZ=Asia/Shanghai
      - WATCHTOWER_CLEANUP=${CLEANUP:-true}
      - WATCHTOWER_POLL_INTERVAL=${POLL_INTERVAL:-3600}
    labels:
      - "com.centurylinklabs.watchtower.enable=false"

  watchtower-notifier:
    image: w254992/watchtower-telegram-monitor:latest
    container_name: watchtower-notifier
    restart: unless-stopped
    network_mode: host
    depends_on:
      - watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - nfs-data:/data
    env_file:
      - .env
    environment:
      - TZ=Asia/Shanghai
    labels:
      - "com.centurylinklabs.watchtower.enable=false"

volumes:
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=127.0.0.1,rw,nfsvers=4
      device: ":/srv/watchtower-shared"
```

**云服务V2 和 云服务器V4 的 `docker-compose.yml`：**

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    environment:
      - WATCHTOWER_NO_STARTUP_MESSAGE=true
      - TZ=Asia/Shanghai
      - WATCHTOWER_CLEANUP=${CLEANUP:-true}
      - WATCHTOWER_POLL_INTERVAL=${POLL_INTERVAL:-3600}
    labels:
      - "com.centurylinklabs.watchtower.enable=false"

  watchtower-notifier:
    image: w254992/watchtower-telegram-monitor:latest
    container_name: watchtower-notifier
    restart: unless-stopped
    network_mode: host
    depends_on:
      - watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - nfs-data:/data
    env_file:
      - .env
    environment:
      - TZ=Asia/Shanghai
    labels:
      - "com.centurylinklabs.watchtower.enable=false"

volumes:
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=100.64.1.10,rw,nfsvers=4  # 京东云的 Tailscale IP
      device: ":/srv/watchtower-shared"
```

#### 第六步：配置环境变量

**每台服务器的 `.env` 文件（唯一区别是 SERVER_NAME）：**

京东云：
```bash
BOT_TOKEN=相同的_bot_token
CHAT_ID=相同的_chat_id
SERVER_NAME=京东云
POLL_INTERVAL=3600
```

云服务V2：
```bash
BOT_TOKEN=相同的_bot_token
CHAT_ID=相同的_chat_id
SERVER_NAME=云服务V2
POLL_INTERVAL=3600
```

云服务器V4：
```bash
BOT_TOKEN=相同的_bot_token
CHAT_ID=相同的_chat_id
SERVER_NAME=云服务器V4
POLL_INTERVAL=3600
```

#### 第七步：启动服务

```bash
# 1. 在京东云启动
cd ~/watchtower
docker compose up -d
docker compose logs -f watchtower-notifier

# 2. 在云服务V2启动
cd ~/watchtower
docker compose up -d
docker compose logs -f watchtower-notifier

# 3. 在云服务器V4启动
cd ~/watchtower
docker compose up -d
docker compose logs -f watchtower-notifier
```

#### 第八步：验证多服务器

在 Telegram 中发送：

```
/servers
```

应该看到：

```
🌐 在线服务器 (3)

🖥️ 京东云 (8个容器)
   最后心跳: 刚刚

🖥️ 云服务V2 (5个容器)
   最后心跳: 30秒前

🖥️ 云服务器V4 (3个容器)
   最后心跳: 1分钟前
```

---

### 方案二：公网 NFS

**适用场景：** 主服务器有公网 IP，其他服务器可直接访问

**风险提示：** 需要正确配置安全组/防火墙，否则存在安全风险

#### 第一步：配置 NFS 服务器

```bash
# 在京东云（公网 IP: 117.72.165.47）

# 1. 安装 NFS
sudo apt-get install -y nfs-kernel-server

# 2. 创建共享目录
sudo mkdir -p /srv/watchtower-shared
sudo chmod 777 /srv/watchtower-shared

# 3. 配置导出（使用公网 IP）
sudo nano /etc/exports
```

**指定服务器 IP（推荐）：**

```
/srv/watchtower-shared 云服务V2的公网IP(rw,sync,no_subtree_check,no_root_squash,insecure)
/srv/watchtower-shared 云服务器V4的公网IP(rw,sync,no_subtree_check,no_root_squash,insecure)
/srv/watchtower-shared 127.0.0.1(rw,sync,no_subtree_check,no_root_squash,insecure)
```

**或允许所有 IP（测试用）：**

```
/srv/watchtower-shared *(rw,sync,no_subtree_check,no_root_squash,insecure)
```

```bash
# 4. 应用配置
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

#### 第二步：配置防火墙和安全组

**1. 服务器防火墙（ufw）：**

```bash
# 允许指定 IP 访问
sudo ufw allow from 云服务V2的IP to any port 2049
sudo ufw allow from 云服务V2的IP to any port 111
sudo ufw allow from 云服务器V4的IP to any port 2049
sudo ufw allow from 云服务器V4的IP to any port 111

# 或允许所有（不推荐）
sudo ufw allow 2049
sudo ufw allow 111
```

**2. 京东云安全组（重要！）：**

登录京东云控制台，添加入站规则：

| 协议 | 端口 | 源地址 | 说明 |
|------|------|--------|------|
| TCP | 2049 | 云服务V2的IP/32 | NFS 主端口 |
| TCP | 111 | 云服务V2的IP/32 | RPC 端口 |
| TCP | 2049 | 云服务器V4的IP/32 | NFS 主端口 |
| TCP | 111 | 云服务器V4的IP/32 | RPC 端口 |

#### 第三步：其他服务器安装客户端

```bash
# 在云服务V2 和 云服务器V4
sudo apt-get install -y nfs-common
```

#### 第四步：测试连接

```bash
# 在云服务V2 测试
showmount -e 117.72.165.47

# 测试挂载
sudo mkdir -p /mnt/test
sudo mount -t nfs 117.72.165.47:/srv/watchtower-shared /mnt/test
ls /mnt/test
sudo touch /mnt/test/test.txt
sudo umount /mnt/test
```

#### 第五步：配置 Docker Compose

**京东云：**

```yaml
volumes:
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=127.0.0.1,rw,nfsvers=4
      device: ":/srv/watchtower-shared"
```

**其他服务器：**

```yaml
volumes:
  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=117.72.165.47,rw,nfsvers=4,insecure
      device: ":/srv/watchtower-shared"
```

---

## 获取 Telegram 凭证

### 获取 Bot Token

1. 在 Telegram 搜索 `@BotFather`
2. 发送 `/newbot`
3. 设置机器人名称和用户名（必须以 `bot` 结尾）
4. 获取 Token（格式：`123456789:ABCdefGHI...`）

**测试 Token：**

```bash
curl "https://api.telegram.org/bot你的TOKEN/getMe"
```

### 获取 Chat ID

**方法 1：使用 @userinfobot（最简单）**

1. 搜索 `@userinfobot`
2. 点击 Start
3. 获取你的 ID

**方法 2：发消息获取**

1. 先给你的 Bot 发送任意消息
2. 访问：`https://api.telegram.org/bot你的TOKEN/getUpdates`
3. 在 JSON 中找到 `chat.id`

**方法 3：命令行**

```bash
TOKEN="你的_bot_token"

# 先给 Bot 发消息，然后运行：
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | \
  grep -o '"chat":{"id":[0-9]*' | \
  grep -o '[0-9]*$'
```

### 测试凭证

```bash
BOT_TOKEN="你的_token"
CHAT_ID="你的_chat_id"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=测试消息"
```

收到消息说明配置正确！

---

## 验证安装

### 1. 检查容器状态

```bash
docker compose ps

# 应该看到：
# watchtower            Up
# watchtower-notifier   Up
```

### 2. 检查日志

```bash
# 查看启动日志
docker compose logs watchtower-notifier | tail -30

# 应该看到 "服务正常运行中"
```

### 3. 检查 Telegram 通知

启动后 10-30 秒内应该收到启动成功通知。

### 4. 测试命令

在 Telegram 发送：

```
/help
```

应该收到命令列表。

### 5. 多服务器验证

```bash
# 查看共享数据
docker exec watchtower-notifier ls -la /data

# 应该看到：
# server_registry.json
# monitor_config.json

# 查看服务器注册表
docker exec watchtower-notifier cat /data/server_registry.json

# 应该看到所有服务器的心跳信息
```

---

## 故障排查

### 问题 1：收不到 Telegram 通知

**检查配置：**

```bash
cat .env
docker exec watchtower-notifier sh -c 'echo $BOT_TOKEN $CHAT_ID'
```

**测试 API：**

```bash
curl "https://api.telegram.org/bot你的TOKEN/getMe"
```

**必须先给 Bot 发送过消息！**

**查看日志：**

```bash
docker logs watchtower-notifier | grep -i error
```

### 问题 2：NFS 连接失败（多服务器）

**Tailscale 方案：**

```bash
# 检查 Tailscale 状态
sudo tailscale status

# 测试连通性
ping 100.64.1.10

# 检查 NFS
showmount -e 100.64.1.10
```

**公网 NFS 方案：**

```bash
# 测试端口
telnet 117.72.165.47 2049

# 检查防火墙
sudo ufw status

# 检查 NFS 导出
sudo exportfs -v

# 确保有 insecure 选项
```

### 问题 3：容器无法启动

```bash
# 查看详细错误
docker logs watchtower-notifier --tail 50

# 检查 Docker socket 权限
ls -la /var/run/docker.sock

# 检查磁盘空间
df -h

# 重建容器
docker compose down -v
docker compose up -d
```

### 问题 4：多服务器数据不同步

```bash
# 检查 NFS 挂载
docker exec watchtower-notifier df -h | grep data

# 查看共享文件
docker exec watchtower-notifier ls -la /data

# 测试写入
docker exec watchtower-notifier sh -c 'echo test > /data/test.txt'

# 在另一台服务器查看
docker exec watchtower-notifier cat /data/test.txt
```

### 问题 5：网络问题（中国大陆）

**配置 Docker 镜像加速：**

```bash
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.mirrors.sjtug.sjtu.edu.cn"
  ]
}
EOF

sudo systemctl restart docker
cd ~/watchtower && docker compose restart
```

**配置代理：**

```yaml
environment:
  - HTTP_PROXY=http://127.0.0.1:7890
  - HTTPS_PROXY=http://127.0.0.1:7890
```

### 问题 6：showmount 超时

```bash
# 检查 NFS 服务
sudo systemctl status nfs-kernel-server

# 检查端口监听
sudo netstat -tulpn | grep -E '2049|111'

# 重启 NFS
sudo systemctl restart nfs-kernel-server
sudo exportfs -ra
```

---

## 常用命令

### Docker Compose

```bash
# 启动
docker compose up -d

# 停止
docker compose down

# 重启
docker compose restart

# 查看日志
docker compose logs -f

# 更新
docker compose pull
docker compose up -d
```

### 查看状态

```bash
# 容器状态
docker compose ps

# 资源使用
docker stats watchtower watchtower-notifier

# 详细信息
docker inspect watchtower-notifier
```

### NFS 管理

```bash
# 查看 NFS 导出
sudo exportfs -v

# 查看挂载点
showmount -e localhost

# 重新加载配置
sudo exportfs -ra

# 重启 NFS
sudo systemctl restart nfs-kernel-server
```

### Tailscale 管理

```bash
# 查看状态
sudo tailscale status

# 查看 IP
tailscale ip -4

# 重启
sudo systemctl restart tailscaled

# 退出网络
sudo tailscale down

# 重新加入
sudo tailscale up
```

---

## 下一步

- 📖 查看 [README.md](../README.md) 了解功能特性
- ⚙️ 查看 [CONFIGURATION.md](CONFIGURATION.md) 了解高级配置
- 🐛 遇到问题？查看 [FAQ.md](FAQ.md)

---

**需要帮助？**

- 🐛 [提交 Issue](https://github.com/Celestials316/watchtower-telegram-monitor/issues)
- 💬 [讨论区](https://github.com/Celestials316/watchtower-telegram-monitor/discussions)
# 安装指南

## 📋 前置要求

- Docker 20.10+
- Docker Compose v2.0+
- Telegram Bot Token 和 Chat ID

## 🚀 安装方式

### 方式 1: 使用 Docker Compose (推荐)

#### 1. 创建工作目录

```bash
mkdir -p ~/watchtower && cd ~/watchtower
```

#### 2. 下载配置文件

```bash
# 下载 docker-compose.yml
curl -O https://raw.githubusercontent.com/yourusername/watchtower-telegram-monitor/main/docker/docker-compose.yml

# 下载环境变量示例
curl -O https://raw.githubusercontent.com/yourusername/watchtower-telegram-monitor/main/config/.env.example

# 重命名为 .env
mv .env.example .env
```

#### 3. 编辑配置

```bash
nano .env
```

填写必填项:
- `BOT_TOKEN`: 你的 Telegram Bot Token
- `CHAT_ID`: 你的 Telegram Chat ID

#### 4. 修改镜像名

编辑 `docker-compose.yml`，将 `yourusername/watchtower-telegram-monitor:latest` 替换为你的实际镜像名。

#### 5. 启动服务

```bash
# 创建数据目录
mkdir -p data

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f
```

---

### 方式 2: 使用 Docker Run

```bash
# 创建数据目录
mkdir -p ~/watchtower/data

# 运行容器
docker run -d \
  --name watchtower-notifier \
  --restart unless-stopped \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v ~/watchtower/data:/data \
  -e BOT_TOKEN="your_bot_token" \
  -e CHAT_ID="your_chat_id" \
  -e SERVER_NAME="My Server" \
  -e POLL_INTERVAL=3600 \
  -e CLEANUP=true \
  -e ENABLE_ROLLBACK=true \
  yourusername/watchtower-telegram-monitor:latest

# 同时需要运行 Watchtower
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_CLEANUP=true \
  -e WATCHTOWER_POLL_INTERVAL=3600 \
  containrrr/watchtower:latest
```

---

### 方式 3: 从源码构建

#### 1. 克隆仓库

```bash
git clone https://github.com/yourusername/watchtower-telegram-monitor.git
cd watchtower-telegram-monitor
```

#### 2. 构建镜像

```bash
docker build -f docker/Dockerfile -t watchtower-telegram-monitor:local .
```

#### 3. 配置并运行

```bash
cp config/.env.example .env
nano .env

# 修改 docker/docker-compose.yml 中的镜像名为 watchtower-telegram-monitor:local
docker compose -f docker/docker-compose.yml up -d
```

---

## 🔧 验证安装

### 1. 检查容器状态

```bash
docker ps | grep watchtower
```

应该看到两个容器在运行:
- `watchtower`
- `watchtower-notifier`

### 2. 查看日志

```bash
# 查看通知服务日志
docker logs watchtower-notifier

# 查看 Watchtower 日志
docker logs watchtower
```

### 3. 检查 Telegram 通知

启动后几秒内，你应该会收到一条启动成功的 Telegram 消息。

---

## 📱 获取 Telegram 凭证

### 获取 Bot Token

1. 在 Telegram 搜索 `@BotFather`
2. 发送 `/newbot` 创建新机器人
3. 按提示设置名称
4. 获得 Token，格式类似: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### 获取 Chat ID

**方法 1: 使用 @userinfobot**
1. 搜索 `@userinfobot`
2. 点击 Start
3. 获取你的 ID

**方法 2: 发消息获取**
1. 给你的 Bot 发送任意消息
2. 访问: `https://api.telegram.org/bot<YourBotToken>/getUpdates`
3. 在返回的 JSON 中找到 `chat.id`

---

## 🎯 监控特定容器

如果只想监控特定容器,编辑 `docker-compose.yml`:

```yaml
services:
  watchtower:
    # ... 其他配置 ...
    command:
      - nginx
      - mysql
      - redis
```

重启服务:

```bash
docker compose restart
```

---

## 🆘 故障排查

### 容器无法启动

```bash
# 查看详细日志
docker logs watchtower-notifier --tail 100

# 检查配置文件
cat .env
```

### 收不到通知

1. 确认 Bot Token 和 Chat ID 正确
2. 确保给 Bot 发送过至少一条消息
3. 检查网络连接

```bash
# 手动测试发送
docker exec watchtower-notifier curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage?chat_id=${CHAT_ID}&text=test"
```

### 权限问题

```bash
# 确保 Docker socket 可访问
ls -la /var/run/docker.sock

# 如果需要,添加权限
sudo chmod 666 /var/run/docker.sock
```

---

## 🔄 更新服务

```bash
cd ~/watchtower

# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d
```

---

## 🗑️ 卸载

```bash
cd ~/watchtower

# 停止并删除容器
docker compose down

# 删除数据(可选)
rm -rf data/

# 删除配置文件(可选)
rm -f .env docker-compose.yml
```

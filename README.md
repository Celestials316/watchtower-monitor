# Docker 容器监控系统

[![Docker Pulls](https://img.shields.io/docker/pulls/w254992/watchtower-telegram-monitor)](https://hub.docker.com/r/w254992/watchtower-telegram-monitor)
[![Docker Image Size](https://img.shields.io/docker/image-size/w254992/watchtower-telegram-monitor)](https://hub.docker.com/r/w254992/watchtower-telegram-monitor)
[![GitHub Stars](https://img.shields.io/github/stars/w254992/watchtower-telegram-monitor?style=social)](https://github.com/w254992/watchtower-telegram-monitor)


自动监控 Docker 容器更新并通过 Telegram 发送**中文通知**，支持版本追踪、自动回滚、状态持久化，**新增交互式命令管理**。

## ✨ 特性

- 🤖 **交互式命令** - 通过 Telegram 直接管理容器（v3.4.0 新增）
- 🌐 **多服务器管理** - 统一 Bot 管理多台服务器（v3.5.0 新增）
- 🔔 **实时通知** - 容器更新成功/失败即时推送
- 📊 **版本追踪** - 记录容器镜像版本变化历史
- 🔄 **自动回滚** - 更新失败时自动恢复旧版本
- 💾 **状态持久化** - 数据库记录容器状态，重启不丢失
- 🎯 **灵活监控** - 支持监控所有容器或指定容器
- 🌐 **中文界面** - 通知消息完全中文化
- 📝 **详细日志** - 实时显示处理过程，方便调试

## 📸 效果预览

### 启动通知
```
🚀 监控服务启动成功

━━━━━━━━━━━━━━━━━━━━
📊 服务信息
   版本: v3.5.0 (多服务器版)
   服务器: 生产服务器
   ID: a1b2c3d4

🎯 监控状态
   容器数: 4
   检查间隔: 60分钟

🤖 交互命令
   发送 /help 查看命令列表
   发送 /servers 查看所有服务器
   发送 /status 查看状态

⏰ 启动时间
   2024-11-06 10:30:00
━━━━━━━━━━━━━━━━━━━━

✅ 服务正常运行中
```

### 交互式命令（v3.4.0+）
```
🤖 多服务器 Docker 监控 Bot v3.5.0

🌐 多服务器管理
当有多个服务器时，执行命令会显示服务器列表供选择

📊 状态查询
/status - 查看服务状态
/servers - 列出所有在线服务器
/containers - 列出所有容器
/config - 查看当前配置

🔄 操作命令
/check - 立即检查更新
/pause - 暂停自动检查
/resume - 恢复自动检查

⚙️ 配置命令
/interval <秒> - 设置检查间隔
/monitor <容器名> - 设置监控容器
/rollback on|off - 开关自动回滚

📝 其他
/logs - 查看最近日志
/help - 显示此帮助

当前版本: v3.5.0
支持多服务器统一管理
```

### 多服务器选择（v3.5.0）
```
请选择要执行 status 的服务器:

🖥️ 生产服务器 (8个容器)
🖥️ 测试服务器 (5个容器)
🖥️ 开发环境 (3个容器)
```

### 更新成功通知
```
[生产服务器] ✨ 容器更新成功

━━━━━━━━━━━━━━━━━━━━
📦 容器名称
   nginx

🎯 镜像信息
   nginx

🔄 版本变更
   1.25.3 (a1b2c3d4e5f6)
   ➜
   1.25.4 (f6e5d4c3b2a1)

⏰ 更新时间
   2024-11-06 11:15:23
━━━━━━━━━━━━━━━━━━━━

✅ 容器已成功启动并运行正常
```

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose v2.0+
- Telegram Bot Token 和 Chat ID

### 5 分钟快速部署

#### 1. 获取 Telegram 凭证

**Bot Token:**
1. 在 Telegram 搜索 `@BotFather`
2. 发送 `/newbot` 创建机器人
3. 获取 Token（格式：`123456789:ABCdefGHI...`）

**Chat ID:**
1. 搜索 `@userinfobot`
2. 点击 Start，获取你的 ID

详细步骤见 [INSTALL.md](docs/INSTALL.md#%EF%B8%8F-获取-telegram-凭证)

#### 2. 创建配置文件

```bash
# 创建工作目录
mkdir -p ~/watchtower && cd ~/watchtower

# 下载配置模板
curl -o docker-compose.yml https://raw.githubusercontent.com/celestials316/watchtower-telegram-monitor/main/docker/docker-compose.yml

# 编辑配置
nano docker-compose.yml
```

**修改以下内容：**
```yaml
environment:
  # 必填 - 替换为你的实际值
  - BOT_TOKEN=your_bot_token_here    # ← 改这里
  - CHAT_ID=your_chat_id_here        # ← 改这里
  
  # 可选 - 服务器名称
  - SERVER_NAME=我的服务器           # ← 多服务器时建议修改
```

保存文件: `Ctrl+O` → `Enter` → `Ctrl+X`

#### 3. 启动服务

```bash
# 创建数据目录
mkdir -p data

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f
```

#### 4. 验证运行

启动后 10-30 秒内，你应该会收到 Telegram 启动成功通知。

```bash
# 检查服务状态
docker compose ps

# 查看实时日志
docker compose logs -f watchtower-notifier
```

#### 5. 使用交互式命令

在 Telegram 中给你的 Bot 发送命令：

```
/help      # 查看所有命令
/status    # 查看服务状态
/servers   # 查看所有服务器（多服务器时）
/check     # 立即检查更新
/containers # 查看容器列表
```

## 📋 配置说明

### 环境变量

| 变量名 | 说明 | 默认值 | 必填 |
|--------|------|--------|------|
| `BOT_TOKEN` | Telegram Bot Token | - | ✅ |
| `CHAT_ID` | Telegram Chat ID | - | ✅ |
| `SERVER_NAME` | 服务器标识名称 | 空 | ❌ |
| `POLL_INTERVAL` | 检查间隔(秒) | 3600 | ❌ |
| `CLEANUP` | 自动清理旧镜像 | true | ❌ |
| `ENABLE_ROLLBACK` | 启用自动回滚 | true | ❌ |
| `MONITORED_CONTAINERS` | 监控容器列表 | 空(全部) | ❌ |

### 监控特定容器

**方式 1: 通过环境变量（推荐）**

```yaml
environment:
  - MONITORED_CONTAINERS=nginx mysql redis
```

**方式 2: 通过 Watchtower 命令**

```yaml
services:
  watchtower:
    command:
      - nginx
      - mysql
      - redis
```

**方式 3: 通过 Telegram 命令（v3.4.0+）**

```
/monitor nginx mysql redis
```

### 代理配置（国内服务器必需）

如果在中国大陆，需要配置代理访问 Telegram：

```yaml
environment:
  - HTTP_PROXY=http://127.0.0.1:7890
  - HTTPS_PROXY=http://127.0.0.1:7890
  - NO_PROXY=localhost,127.0.0.1
```

## 🌐 多服务器部署（v3.5.0）

### 部署架构

所有服务器使用**相同的 Bot Token**，通过 `SERVER_NAME` 区分：

```
┌─────────────────┐
│  Telegram Bot   │ ← 一个 Bot 管理所有服务器
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────┐
    ↓         ↓        ↓        ↓
┌────────┐ ┌────────┐ ┌────────┐
│服务器A │ │服务器B │ │服务器C │
│(生产)  │ │(测试)  │ │(开发)  │
└────────┘ └────────┘ └────────┘
```

### 配置示例

**服务器 1 (生产环境):**
```yaml
environment:
  - BOT_TOKEN=123456:ABC...      # ← 相同
  - CHAT_ID=987654321            # ← 相同
  - SERVER_NAME=生产服务器        # ← 不同
  - POLL_INTERVAL=3600
```

**服务器 2 (测试环境):**
```yaml
environment:
  - BOT_TOKEN=123456:ABC...      # ← 相同
  - CHAT_ID=987654321            # ← 相同
  - SERVER_NAME=测试服务器        # ← 不同
  - POLL_INTERVAL=1800
```

**服务器 3 (开发环境):**
```yaml
environment:
  - BOT_TOKEN=123456:ABC...      # ← 相同
  - CHAT_ID=987654321            # ← 相同
  - SERVER_NAME=开发环境          # ← 不同
  - POLL_INTERVAL=900
```

### 使用方式

1. **查看所有服务器：**
   ```
   /servers
   ```
   返回在线服务器列表和容器数量

2. **执行命令时自动选择：**
   ```
   /status
   ```
   如果只有一个服务器，直接返回结果
   如果有多个服务器，显示选择按钮

3. **通知自动标识来源：**
   ```
   [生产服务器] ✨ 容器更新成功
   [测试服务器] ❌ 容器启动失败
   ```

### 数据共享

多服务器需要共享数据，有两种方案：

**方案 1: 使用共享存储（推荐）**
```yaml
volumes:
  - /mnt/nfs/watchtower-data:/data  # NFS 共享目录
```

**方案 2: 使用 Docker 命名卷（单机多实例）**
```yaml
volumes:
  - watchtower-shared:/data

volumes:
  watchtower-shared:
    external: true
```

## 🔧 管理命令

### Docker Compose 命令

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 重启服务
docker compose restart

# 查看状态
docker compose ps

# 查看日志
docker compose logs -f

# 更新镜像
docker compose pull
docker compose up -d
```

### Telegram 交互命令（v3.4.0+）

```bash
# 状态查询
/status      # 查看服务状态
/servers     # 列出所有在线服务器（v3.5.0）
/containers  # 列出所有容器
/config      # 查看当前配置

# 操作命令
/check       # 立即检查更新
/pause       # 暂停自动检查
/resume      # 恢复自动检查

# 配置命令
/interval 3600           # 设置检查间隔为 1 小时
/monitor nginx mysql     # 设置监控特定容器
/monitor all            # 监控所有容器
/rollback on            # 启用自动回滚
/rollback off           # 禁用自动回滚

# 其他
/logs        # 查看最近日志
/help        # 显示帮助信息
```

## 📖 详细文档

- [安装指南](docs/INSTALL.md) - 详细安装步骤和故障排查
- [配置说明](docs/CONFIGURATION.md) - 高级配置和自定义选项
- [常见问题](docs/FAQ.md) - 疑难解答
- [更新日志](CHANGELOG.md) - 版本历史

## 🔍 工作原理

```
┌─────────────────┐
│   Watchtower    │ ← 定期检查容器镜像更新
└────────┬────────┘
         │ 更新事件
         ↓
┌─────────────────┐
│  监控通知服务    │ ← 监听 Watchtower 日志
│  (本镜像)       │
└────────┬────────┘
         │
         ├─→ 记录容器状态到数据库
         │
         ├─→ 检测容器更新
         │
         ├─→ 验证更新结果
         │
         ├─→ 发送 Telegram 通知
         │
         └─→ 监听 Telegram 命令 (v3.4.0+)
              │
              ├─→ /status  - 查询状态
              ├─→ /check   - 触发检查
              ├─→ /servers - 服务器列表 (v3.5.0)
              └─→ 更多命令...
```

## 🛠️ 高级用法

### Docker Run 方式

```bash
# 先启动 Watchtower
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_CLEANUP=true \
  -e WATCHTOWER_POLL_INTERVAL=3600 \
  containrrr/watchtower:latest

# 再启动通知服务
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
  celestials316/watchtower-telegram-monitor:latest
```

### 配置检查间隔

```bash
# 30 分钟检查一次
POLL_INTERVAL=1800

# 1 小时检查一次（推荐）
POLL_INTERVAL=3600

# 6 小时检查一次
POLL_INTERVAL=21600

# 每天检查一次
POLL_INTERVAL=86400
```

也可以通过 Telegram 命令动态调整：
```
/interval 3600
```

## 🐛 故障排查

### 收不到通知

1. **检查配置**
```bash
docker exec watchtower-notifier sh -c 'echo $BOT_TOKEN $CHAT_ID'
```

2. **手动测试 API**
```bash
curl "https://api.telegram.org/bot你的TOKEN/getMe"
```

3. **确保给 Bot 发送过消息**
   - 必须先在 Telegram 中给 Bot 发送任意消息

4. **查看日志**
```bash
docker logs watchtower-notifier | grep -i error
```

### 容器无法启动

```bash
# 查看详细错误
docker logs watchtower-notifier --tail 50

# 检查 Docker socket 权限
ls -la /var/run/docker.sock

# 检查磁盘空间
df -h
```

### 网络问题（中国大陆）

如果看到 `TLS handshake timeout` 错误，需要配置代理：

```yaml
environment:
  - HTTP_PROXY=http://127.0.0.1:7890
  - HTTPS_PROXY=http://127.0.0.1:7890
```

或配置 Docker 镜像加速器：
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
```

更多问题见 [故障排查文档](docs/INSTALL.md#-故障排查)

## 🔄 更新服务

```bash
cd ~/watchtower

# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d

# 验证版本
docker exec watchtower-notifier sh -c 'head -3 /app/monitor.sh'
```

## 🗑️ 卸载

```bash
cd ~/watchtower

# 停止并删除容器
docker compose down

# 删除数据（可选）
rm -rf data/

# 删除所有文件（可选）
cd .. && rm -rf watchtower/
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📝 更新日志

### v3.5.0 (2024-11-06)
- ✨ 支持多服务器统一管理
- 🌐 新增 `/servers` 命令查看所有在线服务器
- 🎯 命令执行时自动显示服务器选择
- 💓 服务器心跳机制，自动检测在线状态
- 🔧 优化交互式命令体验

### v3.4.0 (2024-11-05)
- ✨ 新增交互式 Telegram 命令支持
- 🤖 支持 13 个实用命令 (/status, /check, /config 等)
- ⚙️ 支持动态配置（检查间隔、监控容器、自动回滚）
- 📊 实时查看服务状态和容器列表
- 🔄 支持暂停/恢复自动检查

### v3.3.0 (2024-11-04)
- ✨ 重构核心逻辑，所有处理内联到主循环
- 🐛 修复管道子shell变量传递问题
- 📝 增强日志输出，实时显示处理步骤
- ⚡ 优化性能，简化架构

### v3.2.1
- 🔧 修复状态数据库写入问题
- 📊 改进版本信息读取逻辑

### v3.0.0
- 🎉 初始版本发布

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 💡 鸣谢

- [Watchtower](https://github.com/containrrr/watchtower) - 自动更新 Docker 容器
- [Telegram Bot API](https://core.telegram.org/bots/api) - 消息推送

## 📞 支持

- 🐛 [提交 Issue](https://github.com/celestials316/watchtower-telegram-monitor/issues)
- 💬 [讨论区](https://github.com/celestials316/watchtower-telegram-monitor/discussions)

---

**如果觉得有帮助，请给个 ⭐️ Star 支持一下！**


```markdown
# 🔔 Watchtower 日志智能通知与容器回滚助手 (Notifier v3.3.0)

[![Docker Pulls](https://img.shields.io/badge/Based%20on-Watchtower-blue)](https://containrrr.dev/watchtower/)
[![Notification](https://img.shields.io/badge/Notify-Telegram-2CA5E0)](https://telegram.org/)
[![License](https://img.shields.io/github/license/YourUsername/YourRepoName)](LICENSE)

## 🌟 项目简介

本项目是一个高度定制化、高可靠的 **Watchtower 增强容器**。它将您强大的 Shell 脚本逻辑封装为轻量级服务，专职于 **实时监控 Watchtower 的日志流**，精准捕捉容器更新事件，并执行 **智能通知** 和 **故障回滚** 策略。

与 Watchtower 自带的简单通知机制相比，本项目提供了一个 **信息完整、全中文、支持自动回滚** 的通知管道，旨在最大限度地保证服务连续性和更新透明度。

## ✨ 核心功能与优势

| 功能名称 | 描述 | 核心价值 |
| :--- | :--- | :--- |
| **故障自动回滚** | **独有！** 容器更新后如果无法正常启动，系统将立即尝试使用 **旧镜像 ID 进行恢复**。 | 最大限度保障服务连续性，将更新风险降至最低。 |
| **精准中文通知** | 通过监听 Docker Socket 日志，精确捕捉更新全过程，发送结构化、全中文的 **更新成功/失败** 通知到 Telegram。 | 通知内容清晰易懂，包含新旧版本 ID 和可选的服务器标记。 |
| **智能版本解析** | 具备对特定应用（如 `danmu-api`）的 **版本号深度解析** 能力，显示真实的软件版本号而非仅是镜像标签。 | 获得更准确、更具参考价值的版本变更信息。 |
| **Watchtower 错误告警** | 实时扫描 Watchtower 日志中的严重错误 (`level=error` / `fatal`)，并立即发送 Telegram 警报。 | 确保您能及时发现并解决监控系统自身的故障。 |

## 📦 仓库目录结构

本仓库包含 Docker 构建文件、核心脚本和详细配置文档：

```

watchtower-telegram-monitor/
├── docker/
│   ├── Dockerfile              \# Notifier 容器的构建文件
│   └── docker-compose.yml      \# 一键部署 Watchtower + Notifier 的配置
├── scripts/
│   ├── monitor.sh              \# 核心监控与通知逻辑脚本
│   └── manage.sh               \# 本地服务管理快捷脚本
├── config/
│   └── .env.example            \# 环境变量配置示例 (TOKEN/ID 等)
├── docs/
│   ├── INSTALL.md              \# 详细的安装和启动指南
│   └── CONFIGURATION.md        \# 所有环境变量和参数的配置说明
├── README.md
└── LICENSE

````

## 📚 使用指南

请参考以下链接，开始部署和配置您的智能监控助手：

* [安装指南](docs/INSTALL.md)
* [配置说明](docs/CONFIGURATION.md)

---

## ⚙️ 维护与管理

部署成功后，您可以使用 `scripts/manage.sh` 脚本进行日常操作：

```bash
# 运行管理菜单
./scripts/manage.sh
````

-----

```
```
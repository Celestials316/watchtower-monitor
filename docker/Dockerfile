
# 文件名: Dockerfile

FROM python:3.11-alpine

LABEL maintainer="Celestials316" \
      description="Docker container monitoring with Telegram notifications (Python version)" \
      version="5.0.0"

# 安装依赖
RUN apk add --no-cache \
    docker-cli \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# 设置时区
ENV TZ=Asia/Shanghai
ENV PYTHONUNBUFFERED=1

# 创建工作目录
WORKDIR /app

# 复制 Python 脚本
COPY scripts/monitor.py /app/monitor.py

# 安装 Python 依赖
RUN pip install --no-cache-dir requests

# 创建数据目录
RUN mkdir -p /data

# 健康检查 - 检查 Python 进程是否运行
HEALTHCHECK --interval=60s --timeout=10s --retries=3 --start-period=15s \
    CMD ps aux | grep -v grep | grep -q 'python.*monitor.py' || exit 1

# 设置入口点
ENTRYPOINT ["python3"]
CMD ["/app/monitor.py"]

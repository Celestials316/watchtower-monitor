#!/bin/sh
# Docker 容器监控通知服务 v3.4.0 - 支持 Telegram 命令交互
# 新增功能: /check, /status, /config, /containers, /interval, /help

echo "正在安装依赖..."
apk add --no-cache curl docker-cli coreutils grep sed tzdata jq >/dev/null 2>&1

TELEGRAM_API="https://api.telegram.org/bot${BOT_TOKEN}"
STATE_FILE="/data/container_state.db"
CONFIG_FILE="/data/bot_config.conf"
LAST_UPDATE_ID_FILE="/data/last_update_id"

# 确保数据目录存在
mkdir -p /data

# 初始化配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
POLL_INTERVAL=${POLL_INTERVAL:-3600}
MONITORED_CONTAINERS=${MONITORED_CONTAINERS:-}
ENABLE_ROLLBACK=${ENABLE_ROLLBACK:-true}
AUTO_CHECK_ENABLED=true
EOF
fi

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    fi
}

# 保存配置
save_config() {
    cat > "$CONFIG_FILE" << EOF
POLL_INTERVAL=${POLL_INTERVAL}
MONITORED_CONTAINERS=${MONITORED_CONTAINERS}
ENABLE_ROLLBACK=${ENABLE_ROLLBACK}
AUTO_CHECK_ENABLED=${AUTO_CHECK_ENABLED}
EOF
}

if [ -n "$SERVER_NAME" ]; then
    SERVER_TAG="<b>[${SERVER_NAME}]</b> "
else
    SERVER_TAG=""
fi

send_telegram() {
    message="$1"
    reply_to="${2:-}"
    max_retries=3
    retry=0
    wait_time=5

    while [ $retry -lt $max_retries ]; do
        if [ -n "$reply_to" ]; then
            response=$(curl -s -w "\n%{http_code}" -X POST "$TELEGRAM_API/sendMessage" \
                --data-urlencode "chat_id=${CHAT_ID}" \
                --data-urlencode "text=${SERVER_TAG}${message}" \
                --data-urlencode "parse_mode=HTML" \
                --data-urlencode "reply_to_message_id=${reply_to}" \
                --connect-timeout 10 --max-time 30 2>&1)
        else
            response=$(curl -s -w "\n%{http_code}" -X POST "$TELEGRAM_API/sendMessage" \
                --data-urlencode "chat_id=${CHAT_ID}" \
                --data-urlencode "text=${SERVER_TAG}${message}" \
                --data-urlencode "parse_mode=HTML" \
                --connect-timeout 10 --max-time 30 2>&1)
        fi
        
        curl_exit_code=$?
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        
        if [ $curl_exit_code -ne 0 ]; then
            echo "  ✗ Curl 执行失败 (退出码: $curl_exit_code)" >&2
        elif [ "$http_code" = "200" ]; then
            if echo "$body" | grep -q '"ok":true'; then
                echo "  ✓ Telegram 通知发送成功"
                return 0
            fi
        fi

        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            sleep $wait_time
            wait_time=$((wait_time * 2))
        fi
    done

    return 1
}

get_time() { date '+%Y-%m-%d %H:%M:%S'; }
get_image_name() { echo "$1" | sed 's/:.*$//'; }
get_short_id() { echo "$1" | sed 's/sha256://' | head -c 12 || echo "unknown"; }

# 获取 Telegram 更新
get_updates() {
    last_update_id=0
    if [ -f "$LAST_UPDATE_ID_FILE" ]; then
        last_update_id=$(cat "$LAST_UPDATE_ID_FILE")
    fi
    
    offset=$((last_update_id + 1))
    updates=$(curl -s "$TELEGRAM_API/getUpdates?offset=$offset&timeout=5" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$updates" ]; then
        echo "$updates"
    fi
}

# 处理命令
process_command() {
    cmd="$1"
    msg_id="$2"
    user_id="$3"
    
    # 验证用户权限
    if [ "$user_id" != "$CHAT_ID" ]; then
        send_telegram "⛔ 无权限执行命令" "$msg_id"
        return
    fi
    
    case "$cmd" in
        /start|/help)
            help_msg="🤖 <b>Docker 监控 Bot 命令列表</b>

<b>📊 状态查询</b>
/status - 查看服务状态
/containers - 列出所有容器
/config - 查看当前配置

<b>🔄 操作命令</b>
/check - 立即检查更新
/update - 强制更新指定容器
/pause - 暂停自动检查
/resume - 恢复自动检查

<b>⚙️ 配置命令</b>
/interval &lt;秒&gt; - 设置检查间隔
  示例: /interval 1800

/monitor &lt;容器名&gt; - 设置监控容器
  示例: /monitor nginx mysql
  留空监控所有: /monitor all

/rollback on|off - 开关自动回滚

<b>📝 其他</b>
/logs - 查看最近日志
/help - 显示此帮助

当前版本: v3.4.0"
            send_telegram "$help_msg" "$msg_id"
            ;;
            
        /status)
            load_config
            container_count=$(docker ps --format '{{.Names}}' | grep -vE '^watchtower|^watchtower-notifier$' | wc -l)
            watchtower_status=$(docker inspect -f '{{.State.Status}}' watchtower 2>/dev/null || echo "unknown")
            
            status_msg="📊 <b>服务状态</b>

━━━━━━━━━━━━━━━━━━━━
🎯 <b>监控服务</b>
   状态: <code>$([ "$watchtower_status" = "running" ] && echo "运行中 ✅" || echo "已停止 ❌")</code>
   自动检查: <code>$([ "$AUTO_CHECK_ENABLED" = "true" ] && echo "已启用 ✅" || echo "已暂停 ⏸️")</code>

📦 <b>容器监控</b>
   容器数: <code>$container_count</code>
   检查间隔: <code>$((POLL_INTERVAL / 60)) 分钟</code>

🔄 <b>功能状态</b>
   自动回滚: <code>$([ "$ENABLE_ROLLBACK" = "true" ] && echo "已启用 ✅" || echo "已禁用 ❌")</code>
   自动清理: <code>$([ "$CLEANUP" = "true" ] && echo "已启用 ✅" || echo "已禁用 ❌")</code>

⏰ <b>服务器时间</b>
   <code>$(get_time)</code>
━━━━━━━━━━━━━━━━━━━━"
            send_telegram "$status_msg" "$msg_id"
            ;;
            
        /containers)
            containers=$(docker ps --format '{{.Names}}|||{{.Image}}|||{{.Status}}' | grep -vE '^watchtower' | head -20)
            
            if [ -z "$containers" ]; then
                send_telegram "📦 当前没有运行中的容器" "$msg_id"
                return
            fi
            
            containers_msg="📦 <b>运行中的容器</b>

━━━━━━━━━━━━━━━━━━━━"
            
            echo "$containers" | while IFS='|||' read -r name image status; do
                containers_msg="$containers_msg
🔹 <code>$name</code>
   镜像: <code>$image</code>
   状态: $status
"
            done
            
            count=$(echo "$containers" | wc -l)
            containers_msg="$containers_msg
━━━━━━━━━━━━━━━━━━━━
共 <b>$count</b> 个容器"
            
            send_telegram "$containers_msg" "$msg_id"
            ;;
            
        /config)
            load_config
            
            if [ -n "$MONITORED_CONTAINERS" ]; then
                monitor_info="特定容器: <code>$MONITORED_CONTAINERS</code>"
            else
                monitor_info="所有容器"
            fi
            
            config_msg="⚙️ <b>当前配置</b>

━━━━━━━━━━━━━━━━━━━━
🕐 <b>检查间隔</b>
   <code>$((POLL_INTERVAL / 60))</code> 分钟 (<code>${POLL_INTERVAL}秒</code>)

📦 <b>监控范围</b>
   $monitor_info

🔄 <b>功能开关</b>
   自动回滚: <code>$([ "$ENABLE_ROLLBACK" = "true" ] && echo "✅ 已启用" || echo "❌ 已禁用")</code>
   自动清理: <code>$([ "$CLEANUP" = "true" ] && echo "✅ 已启用" || echo "❌ 已禁用")</code>
   自动检查: <code>$([ "$AUTO_CHECK_ENABLED" = "true" ] && echo "✅ 已启用" || echo "⏸️ 已暂停")</code>
━━━━━━━━━━━━━━━━━━━━

使用 /help 查看配置命令"
            send_telegram "$config_msg" "$msg_id"
            ;;
            
        /check)
            send_telegram "🔄 正在手动检查更新..." "$msg_id"
            
            # 触发 watchtower 立即检查
            docker kill -s SIGHUP watchtower 2>/dev/null || {
                send_telegram "❌ 触发检查失败，Watchtower 可能未运行" "$msg_id"
                return
            }
            
            send_telegram "✅ 已触发检查，请稍候查看结果" "$msg_id"
            ;;
            
        /pause)
            load_config
            AUTO_CHECK_ENABLED=false
            save_config
            send_telegram "⏸️ 自动检查已暂停

使用 /resume 恢复自动检查
使用 /check 可手动触发检查" "$msg_id"
            ;;
            
        /resume)
            load_config
            AUTO_CHECK_ENABLED=true
            save_config
            send_telegram "▶️ 自动检查已恢复

检查间隔: <code>$((POLL_INTERVAL / 60))</code> 分钟" "$msg_id"
            ;;
            
        /interval*)
            new_interval=$(echo "$cmd" | awk '{print $2}')
            
            if [ -z "$new_interval" ] || ! echo "$new_interval" | grep -qE '^[0-9]+$'; then
                send_telegram "❌ 请提供有效的秒数

用法: /interval &lt;秒&gt;
示例:
  /interval 1800  (30分钟)
  /interval 3600  (1小时)
  /interval 21600 (6小时)" "$msg_id"
                return
            fi
            
            if [ "$new_interval" -lt 300 ]; then
                send_telegram "⚠️ 间隔不能小于 300 秒 (5分钟)" "$msg_id"
                return
            fi
            
            load_config
            old_interval=$POLL_INTERVAL
            POLL_INTERVAL=$new_interval
            save_config
            
            # 更新 Watchtower 环境变量（需要重启容器才能生效）
            send_telegram "✅ 检查间隔已更新

旧值: <code>$((old_interval / 60))</code> 分钟
新值: <code>$((new_interval / 60))</code> 分钟

⚠️ <b>注意</b>: 需要重启服务才能生效
命令: <code>docker compose restart</code>" "$msg_id"
            ;;
            
        /monitor*)
            containers=$(echo "$cmd" | cut -d' ' -f2-)
            
            if [ -z "$containers" ] || [ "$containers" = "/monitor" ]; then
                send_telegram "❌ 请指定容器名称

用法: /monitor &lt;容器名&gt; [容器名2...]
示例:
  /monitor nginx mysql redis
  /monitor all  (监控所有)" "$msg_id"
                return
            fi
            
            load_config
            
            if [ "$containers" = "all" ]; then
                MONITORED_CONTAINERS=""
                save_config
                send_telegram "✅ 已设置为监控所有容器

⚠️ 需要重启服务才能生效" "$msg_id"
            else
                MONITORED_CONTAINERS="$containers"
                save_config
                send_telegram "✅ 监控容器已更新

监控列表: <code>$containers</code>

⚠️ 需要重启服务才能生效
并修改 docker-compose.yml 的 command 部分" "$msg_id"
            fi
            ;;
            
        /rollback*)
            switch=$(echo "$cmd" | awk '{print $2}')
            
            if [ "$switch" != "on" ] && [ "$switch" != "off" ]; then
                send_telegram "❌ 用法: /rollback on|off

示例:
  /rollback on  - 启用自动回滚
  /rollback off - 禁用自动回滚" "$msg_id"
                return
            fi
            
            load_config
            
            if [ "$switch" = "on" ]; then
                ENABLE_ROLLBACK=true
                save_config
                send_telegram "✅ 自动回滚已启用

更新失败时将自动恢复旧版本" "$msg_id"
            else
                ENABLE_ROLLBACK=false
                save_config
                send_telegram "⚠️ 自动回滚已禁用

更新失败时需要手动处理" "$msg_id"
            fi
            ;;
            
        /logs)
            logs=$(docker logs watchtower --tail 20 2>&1 | tail -10)
            
            logs_msg="📝 <b>最近日志</b> (最后10行)

━━━━━━━━━━━━━━━━━━━━
<code>$logs</code>
━━━━━━━━━━━━━━━━━━━━

查看完整日志:
<code>docker logs watchtower</code>"
            
            send_telegram "$logs_msg" "$msg_id"
            ;;
            
        *)
            send_telegram "❌ 未知命令: <code>$cmd</code>

使用 /help 查看可用命令" "$msg_id"
            ;;
    esac
}

# 命令监听后台任务
command_listener() {
    echo "启动命令监听器..."
    
    while true; do
        updates=$(get_updates)
        
        if [ -n "$updates" ] && echo "$updates" | grep -q '"ok":true'; then
            # 解析每个更新
            echo "$updates" | jq -r '.result[] | @base64' 2>/dev/null | while read -r update; do
                decoded=$(echo "$update" | base64 -d 2>/dev/null)
                
                update_id=$(echo "$decoded" | jq -r '.update_id' 2>/dev/null)
                message=$(echo "$decoded" | jq -r '.message.text // empty' 2>/dev/null)
                msg_id=$(echo "$decoded" | jq -r '.message.message_id // empty' 2>/dev/null)
                user_id=$(echo "$decoded" | jq -r '.message.from.id // empty' 2>/dev/null)
                
                if [ -n "$message" ] && [ -n "$update_id" ]; then
                    echo "[$(date '+%H:%M:%S')] 收到命令: $message (来自: $user_id)"
                    
                    # 保存最新的 update_id
                    echo "$update_id" > "$LAST_UPDATE_ID_FILE"
                    
                    # 处理命令
                    if echo "$message" | grep -q '^/'; then
                        process_command "$message" "$msg_id" "$user_id"
                    fi
                fi
            done
        fi
        
        sleep 2
    done
}

# 其他函数保持不变（从原 monitor.sh 复制）
get_danmu_version() {
    container_name="$1"
    check_running="${2:-true}"
    
    if ! echo "$container_name" | grep -qE "danmu-api|danmu_api"; then
        echo ""
        return
    fi
    
    version=""
    
    if [ "$check_running" = "true" ]; then
        for i in $(seq 1 30); do
            if docker exec "$container_name" test -f /app/danmu_api/configs/globals.js 2>/dev/null; then
                break
            fi
            sleep 1
        done
    fi
    
    version=$(docker exec "$container_name" cat /app/danmu_api/configs/globals.js 2>/dev/null | \
              grep -m 1 "VERSION:" | sed -E "s/.*VERSION: '([^']+)'.*/\1/" 2>/dev/null || echo "")
    
    if [ -z "$version" ]; then
        image_id=$(docker inspect --format='{{.Image}}' "$container_name" 2>/dev/null)
        if [ -n "$image_id" ] && [ "$image_id" != "sha256:unknown" ]; then
            version=$(docker run --rm --entrypoint cat "$image_id" \
                      /app/danmu_api/configs/globals.js 2>/dev/null | \
                      grep -m 1 "VERSION:" | sed -E "s/.*VERSION: '([^']+)'.*/\1/" 2>/dev/null || echo "")
        fi
    fi
    
    echo "$version"
}

format_version() {
    img_tag="$1"
    img_id="$2"
    container_name="$3"

    tag=$(echo "$img_tag" | grep -oE ':[^:]+$' | sed 's/://' || echo "latest")
    id_short=$(get_short_id "$img_id")
    
    if echo "$container_name" | grep -qE "danmu-api|danmu_api"; then
        real_version=$(get_danmu_version "$container_name")
        if [ -n "$real_version" ]; then
            echo "v${real_version} (${id_short})"
            return
        fi
    fi

    echo "$tag ($id_short)"
}

save_container_state() {
    container="$1"
    image_tag="$2"
    image_id="$3"
    version_info="$4"

    if [ ! -f "$STATE_FILE" ]; then
        touch "$STATE_FILE" || {
            echo "  ✗ 无法创建状态文件" >&2
            return 1
        }
    fi

    echo "$container|$image_tag|$image_id|$version_info|$(date +%s)" >> "$STATE_FILE"
}

get_container_state() {
    container="$1"

    if [ ! -f "$STATE_FILE" ]; then
        echo "unknown:tag|sha256:unknown|"
        return
    fi

    state=$(grep "^${container}|" "$STATE_FILE" 2>/dev/null | tail -n 1)
    if [ -z "$state" ]; then
        echo "unknown:tag|sha256:unknown|"
        return
    fi

    echo "$state" | cut -d'|' -f2,3,4
}

cleanup_old_states() {
    if [ ! -f "$STATE_FILE" ]; then
        return
    fi

    cutoff_time=$(( $(date +%s) - 604800 ))
    temp_file="${STATE_FILE}.tmp"

    : > "$temp_file"

    if [ -s "$STATE_FILE" ]; then
        while IFS='|' read -r container image_tag image_id version_info timestamp || [ -n "$container" ]; do
            [ -z "$container" ] && continue
            
            if echo "$timestamp" | grep -qE '^[0-9]+$' && [ "$timestamp" -ge "$cutoff_time" ]; then
                echo "$container|$image_tag|$image_id|$version_info|$timestamp" >> "$temp_file"
            fi
        done < "$STATE_FILE"
    fi

    if [ -f "$temp_file" ]; then
        mv "$temp_file" "$STATE_FILE" 2>/dev/null || {
            echo "  ✗ 无法更新状态文件" >&2
            rm -f "$temp_file"
        }
    fi
}

echo "=========================================="
echo "Docker 容器监控通知服务 v3.4.0"
echo "支持 Telegram 命令交互"
echo "服务器: ${SERVER_NAME:-N/A}"
echo "启动时间: $(get_time)"
echo "=========================================="
echo ""

load_config
cleanup_old_states

echo "正在等待 watchtower 容器完全启动..."
while true; do
    if docker inspect -f '{{.State.Running}}' watchtower 2>/dev/null | grep -q "true"; then
        echo "Watchtower 已启动，准备监控日志"
        break
    else
        sleep 2
    fi
done

echo "正在初始化容器状态数据库..."
for container in $(docker ps --format '{{.Names}}'); do
    if [ "$container" = "watchtower" ] || [ "$container" = "watchtower-notifier" ]; then
        continue
    fi

    image_tag=$(docker inspect --format='{{.Config.Image}}' "$container" 2>/dev/null || echo "unknown:tag")
    image_id=$(docker inspect --format='{{.Image}}' "$container" 2>/dev/null || echo "sha256:unknown")
    
    version_info=$(get_danmu_version "$container" "false")
    
    save_container_state "$container" "$image_tag" "$image_id" "$version_info"
    
    if [ -n "$version_info" ]; then
        echo "  → 已保存 $container 的状态到数据库 (版本: v${version_info})"
    else
        echo "  → 已保存 $container 的状态到数据库"
    fi
done

container_count=$(docker ps --format '{{.Names}}' | grep -vE '^watchtower|^watchtower-notifier$' | wc -l)
echo "初始化完成，已记录 ${container_count} 个容器状态"

startup_message="🚀 <b>监控服务启动成功</b>

━━━━━━━━━━━━━━━━━━━━
📊 <b>服务信息</b>
   版本: <code>v3.4.0</code> (支持命令)

🎯 <b>监控状态</b>
   容器数: <code>${container_count}</code>
   检查间隔: <code>$((POLL_INTERVAL / 60))分钟</code>

🤖 <b>交互命令</b>
   发送 /help 查看命令列表
   发送 /status 查看状态

⏰ <b>启动时间</b>
   <code>$(get_time)</code>
━━━━━━━━━━━━━━━━━━━━

✅ 服务正常运行中"

send_telegram "$startup_message"

# 在后台启动命令监听器
command_listener &
LISTENER_PID=$!

echo "命令监听器已启动 (PID: $LISTENER_PID)"
echo "开始监控 Watchtower 日志..."

cleanup() {
    echo "收到退出信号，正在清理..."
    kill $LISTENER_PID 2>/dev/null
    rm -f /tmp/session_data.txt
    exit 0
}

trap cleanup INT TERM

# 主循环保持不变（监控更新逻辑）
docker logs -f --tail 0 watchtower 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%H:%M:%S')] $line"

    if echo "$line" | grep -q "Stopping /"; then
        container_name=$(echo "$line" | sed -n 's/.*Stopping \/\([^ ]*\).*/\1/p' | head -n1)
        if [ -n "$container_name" ]; then
            echo "[$(date '+%H:%M:%S')] → 捕获到停止: $container_name"

            old_state=$(get_container_state "$container_name")
            old_image_tag=$(echo "$old_state" | cut -d'|' -f1)
            old_image_id=$(echo "$old_state" | cut -d'|' -f2)
            old_version_info=$(echo "$old_state" | cut -d'|' -f3)

            echo "${container_name}|${old_image_tag}|${old_image_id}|${old_version_info}" >> /tmp/session_data.txt

            if [ -n "$old_version_info" ]; then
                echo "[$(date '+%H:%M:%S')]   → 已暂存旧信息: $old_image_tag ($old_image_id) v${old_version_info}"
            else
                echo "[$(date '+%H:%M:%S')]   → 已暂存旧信息: $old_image_tag ($old_image_id)"
            fi
        fi
    fi

    if echo "$line" | grep -q "Session done"; then
        updated=$(echo "$line" | grep -oP '(?<=Updated=)[0-9]+' || echo "0")

        echo "[$(date '+%H:%M:%S')] → Session 完成: Updated=$updated"

        if [ "$updated" -gt 0 ] && [ -f /tmp/session_data.txt ]; then
            echo "[$(date '+%H:%M:%S')] → 发现 ${updated} 处更新，立即处理..."
            
            while IFS='|' read -r container_name old_tag_full old_id_full old_version_info; do
                [ -z "$container_name" ] && continue
                
                echo "[$(date '+%H:%M:%S')] → 处理容器: $container_name"
                sleep 5
                
                for i in $(seq 1 60); do
                    status=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null || echo "false")
                    if [ "$status" = "true" ]; then
                        echo "[$(date '+%H:%M:%S')]   → 容器已启动"
                        sleep 5
                        break
                    fi
                    sleep 1
                done
                
                status=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null || echo "false")
                new_tag_full=$(docker inspect --format='{{.Config.Image}}' "$container_name" 2>/dev/null || echo "unknown:tag")
                new_id_full=$(docker inspect --format='{{.Image}}' "$container_name" 2>/dev/null || echo "sha256:unknown")
                
                new_version_info=""
                if echo "$container_name" | grep -qE "danmu-api|danmu_api"; then
                    if [ "$status" = "true" ]; then
                        new_version_info=$(get_danmu_version "$container_name" "true")
                    fi
                fi
                
                echo "$container_name|$new_tag_full|$new_id_full|$new_version_info|$(date +%s)" >> "$STATE_FILE"
                
                img_name=$(echo "$new_tag_full" | sed 's/:.*$//')
                time=$(date '+%Y-%m-%d %H:%M:%S')
                
                old_tag=$(echo "$old_tag_full" | grep -oE ':[^:]+$' | sed 's/://' || echo "latest")
                new_tag=$(echo "$new_tag_full" | grep -oE ':[^:]+$' | sed 's/://' || echo "latest")
                old_id_short=$(echo "$old_id_full" | sed 's/sha256://' | head -c 12)
                new_id_short=$(echo "$new_id_full" | sed 's/sha256://' | head -c 12)
                
                if [ -n "$old_version_info" ]; then
                    old_ver_display="v${old_version_info} (${old_id_short})"
                else
                    old_ver_display="$old_tag ($old_id_short)"
                fi
                
                if [ -n "$new_version_info" ]; then
                    new_ver_display="v${new_version_info} (${new_id_short})"
                else
                    new_ver_display="$new_tag ($new_id_short)"
                fi
                
                if [ "$status" = "true" ]; then
                    message="✨ <b>容器更新成功</b>

━━━━━━━━━━━━━━━━━━━━
📦 <b>容器名称</b>
   <code>${container_name}</code>

🎯 <b>镜像信息</b>
   <code>${img_name}</code>

🔄 <b>版本变更</b>
   <code>${old_ver_display}</code>
   ➜
   <code>${new_ver_display}</code>

⏰ <b>更新时间</b>
   <code>${time}</code>
━━━━━━━━━━━━━━━━━━━━

✅ 容器已成功启动并运行正常"
                    
                    echo "[$(date '+%H:%M:%S')]   → 发送成功通知..."
                else
                    message="❌ <b>容器启动失败</b>

━━━━━━━━━━━━━━━━━━━━
📦 <b>容器名称</b>
   <code>${container_name}</code>

🎯 <b>镜像信息</b>
   <code>${img_name}</code>

🔄 <b>版本变更</b>
   旧: <code>${old_ver_display}</code>
   新: <code>${new_ver_display}</code>

⏰ <b>更新时间</b>
   <code>${time}</code>
━━━━━━━━━━━━━━━━━━━━

⚠️ 更新后无法启动
💡 检查: <code>docker logs ${container_name}</code>"
                    
                    echo "[$(date '+%H:%M:%S')]   → 发送失败通知..."
                fi
                
                send_telegram "$message"
                
            done < /tmp/session_data.txt
            
            rm -f /tmp/session_data.txt
            echo "[$(date '+%H:%M:%S')] → 所有通知已处理完成"
            
        elif [ "$updated" -eq 0 ]; then
            rm -f /tmp/session_data.txt 2>/dev/null
        fi
    fi

    if echo "$line" | grep -qiE "level=error.*fatal|level=fatal"; then
        if echo "$line" | grep -qiE "Skipping|Already up to date|No new images|connection refused.*timeout"; then
            continue
        fi
        
        container_name=$(echo "$line" | sed -n 's/.*container[=: ]\+\([a-zA-Z0-9_.\-]\+\).*/\1/p' | head -n1)
        
        error=$(echo "$line" | sed -n 's/.*msg="\([^"]*\)".*/\1/p' | head -c 200)
        [ -z "$error" ] && error=$(echo "$line" | grep -oE "error=.*" | head -c 200)
        [ -z "$error" ] && error=$(echo "$line" | head -c 200)

        if [ -n "$container_name" ] && [ "$container_name" != "watchtower" ] && [ "$container_name" != "watchtower-notifier" ]; then
            send_telegram "⚠️ <b>Watchtower 严重错误</b>

━━━━━━━━━━━━━━━━━━━━
📦 <b>容器</b>: <code>$container_name</code>
🔴 <b>错误</b>: <code>$error</code>
🕐 <b>时间</b>: <code>$(get_time)</code>
━━━━━━━━━━━━━━━━━━━━"
        fi
    fi
done

cleanup
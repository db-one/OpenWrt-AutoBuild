#!/bin/bash
# GitHub Actions SSH 调试脚本

set -eo pipefail

echo "🛠️ 正在设置 SSH 调试环境..."

TIMEOUT=1800        # 保持运行时间
CHECK_INTERVAL=30   # 检查间隔30秒
TIME_REMAINING=$TIMEOUT
SESSION_ACTIVE=true

# Web 终端相关变量
WEB_LINE=""
TTYD_PID=""
CLOUDFLARED_PID=""
WEB_TERMINAL_PORT="${WEB_TERMINAL_PORT:-7681}"

# 清理函数
cleanup() {
  # 清理 Web 终端进程
  echo "❌ 正在关闭 cloudflared 进程..."
  [ -n "${CLOUDFLARED_PID:-}" ] && kill "${CLOUDFLARED_PID}" 2>/dev/null || true

  echo "❌ 正在关闭 ttyd 进程..."
  [ -n "${TTYD_PID:-}" ] && kill "${TTYD_PID}" 2>/dev/null || true

  # 清理 tmate 会话
  echo "❌ 正在关闭 SSH 会话..."
  tmate -S "$TMATE_SOCK" kill-server 2>/dev/null || true
  rm -f "$TMATE_SOCK"
}

# 设置 Web 终端函数
setup_web_terminal() {
  echo "🌐 正在设置 Web 终端 (ttyd + trycloudflare)..."
  
  local arch ttyd_url cf_url
  arch="$(uname -m)"
  case "${arch}" in
    x86_64)
      ttyd_url="https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64"
      cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
      ;;
    aarch64|arm64)
      ttyd_url="https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.aarch64"
      cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
      ;;
    *)
      echo "⚠️  不支持的架构: ${arch}，Web 终端不可用"
      return 0
      ;;
  esac

  # 创建临时目录
  local temp_dir="/tmp/webterm-$(date +%s)"
  mkdir -p "${temp_dir}"
  
  # 下载二进制文件
  if ! curl -fsSL --retry 3 --connect-timeout 15 "${ttyd_url}" -o "${temp_dir}/ttyd"; then
    echo "⚠️  下载 ttyd 失败，Web 终端不可用"
    return 0
  fi
  if ! curl -fsSL --retry 3 --connect-timeout 15 "${cf_url}" -o "${temp_dir}/cloudflared"; then
    echo "⚠️  下载 cloudflared 失败，Web 终端不可用"
    return 0
  fi
  chmod +x "${temp_dir}/ttyd" "${temp_dir}/cloudflared" || true

  # 启动 ttyd
  "${temp_dir}/ttyd" -o -p "${WEB_TERMINAL_PORT}" -i 127.0.0.1 -W \
    bash -lc 'cd "'"${GITHUB_WORKSPACE}"'" 2>/dev/null || true; bash -l' \
    >"${temp_dir}/ttyd.log" 2>&1 &
  TTYD_PID=$!
  
  # 启动 cloudflared
  "${temp_dir}/cloudflared" tunnel --url "http://127.0.0.1:${WEB_TERMINAL_PORT}" --no-autoupdate \
    >"${temp_dir}/cloudflared.log" 2>&1 &
  CLOUDFLARED_PID=$!

  # 等待获取公网 URL
  local i
  for i in $(seq 1 120); do
    WEB_LINE="$(awk 'match($0, /https:\/\/[-0-9a-z]+\.trycloudflare\.com/) {print substr($0, RSTART, RLENGTH); exit}' "${temp_dir}/cloudflared.log" 2>/dev/null | tr -d '\r' || true)"
    [ -n "${WEB_LINE}" ] && break
    
    if [ -n "${CLOUDFLARED_PID:-}" ] && ! kill -0 "${CLOUDFLARED_PID}" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  
  if [ -z "${WEB_LINE}" ]; then
    echo "⚠️  无法获取 Web URL，请使用 SSH 连接"
    # 清理已启动的进程
    if [ -n "${TTYD_PID:-}" ] && kill -0 "${TTYD_PID}" 2>/dev/null; then
      kill "${TTYD_PID}" 2>/dev/null || true
    fi
    if [ -n "${CLOUDFLARED_PID:-}" ] && kill -0 "${CLOUDFLARED_PID}" 2>/dev/null; then
      kill "${CLOUDFLARED_PID}" 2>/dev/null || true
    fi
    return 0
  fi
  
  echo "✅ Web 终端已就绪"
  return 0
}

# 安装 tmate
if ! command -v tmate &> /dev/null; then
  sudo apt-get update >/dev/null 2>&1
  sudo apt-get install -y tmate >/dev/null 2>&1
fi

# 生成 SSH 密钥
mkdir -p ~/.ssh
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -q
fi

# 创建唯一会话
SESSION_ID="debug-$(date +%H%M%S)"
TMATE_SOCK="/tmp/tmate-${SESSION_ID}.sock"

# 启动 tmate 会话
tmate -S "$TMATE_SOCK" new-session -d -s "$SESSION_ID"
tmate -S "$TMATE_SOCK" wait tmate-ready

# 获取连接信息
SSH_INFO=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}')
SSH_CMD=$(echo "$SSH_INFO" | cut -d ' ' -f2)

# 设置 Web 终端
setup_web_terminal || true

# 发送通知（可选）
if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
  echo "发送 Telegram 通知..."
  message="🖥️ SSH 调试会话已启动
  🔗 SSH 连接命令：
  ssh -o StrictHostKeyChecking=no $SSH_CMD"
  
  if [ -n "${WEB_LINE}" ]; then
    message="${message}
  🌐 Web 连接：
  ${WEB_LINE}"
  fi
  
  message="${message}
  ⏱️ 超时：30分钟
  📁 目录：$GITHUB_WORKSPACE"
  
  curl --silent --output /dev/null \
  -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d chat_id="$TELEGRAM_CHAT_ID" \
  -d text="$message"
  echo ""
fi

# 状态跟踪变量
ssh_attached_once=0

# 主循环
while [ $TIME_REMAINING -gt 0 ] && [ "$SESSION_ACTIVE" = true ]; do
    MINUTES=$((TIME_REMAINING / 60))
    SECONDS=$((TIME_REMAINING % 60))

    # 检查当前会话是否有连接
    TTYD_CONNECTIONS=$(ss -tn state established "sport = :7681" 2>/dev/null | tail -n +2 | wc -l)

    if [ "$TTYD_CONNECTIONS" -gt 0 ]; then
        ssh_attached_once=1
        echo "Web连接中..."
    elif [ "${ssh_attached_once}" -eq 1 ]; then
        echo "🔐 用户已断开所有连接，继续执行..."
    fi

    # 检查会话是否还存在
    if ! tmate -S "$TMATE_SOCK" has-session -t "$SESSION_ID" 2>/dev/null; then
        echo "❌ SSH 会话已结束，继续执行..."
        SESSION_ACTIVE=false
        break
    fi

    # 检查 Web 进程是否还在运行
    if [ -n "${WEB_LINE}" ] && [ -n "${TTYD_PID:-}" ] && ! kill -0 "${TTYD_PID}" 2>/dev/null; then
        echo "🌐 Web 终端进程已结束，继续执行..."
        SESSION_ACTIVE=false
        break
    fi

    # 显示完整信息
    echo ""
    echo "🔐 SSH 调试会话信息"
    echo ""
    echo "会话ID: $SESSION_ID"
    echo "连接命令:"
    echo "ssh -o StrictHostKeyChecking=no $SSH_CMD"
    echo ""
    if [ -n "${WEB_LINE}" ]; then
        echo "🌐 Web 连接:"
        echo "${WEB_LINE}"
    fi
    echo ""
    echo "  📋 可用命令:"
    echo "    • cd openwrt      - 进入项目目录"
    echo "    • make menuconfig - 开始配置软件包"
    echo "    • pwd             - 查看当前目录"
    echo "    • ls -la          - 查看文件列表"
    echo ""
    echo "  ⏰ 剩余时间: ${MINUTES}分${SECONDS}秒"
    # 超时提示（仅在未通过 SSH 连接时显示）
    if [ ${ssh_attached_once} -eq 0 ]; then
        echo "  ⚠️  如果未连接，将自动继续"
    else
        echo "  ✅ 已连接，随时可输入 exit 或 Ctrl+D 退出"
    fi
    echo ""
    echo "用终端连接SSH，或点击Web链接，然后以[q]或[ctrl+c]开始和[ctrl+d]结束"
    echo "想要快速跳过此步骤，只需连接SSH/Web并退出即可"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # 等待
    sleep $CHECK_INTERVAL
    TIME_REMAINING=$((TIME_REMAINING - CHECK_INTERVAL))
done

# 如果超时但会话还在
if [ $TIME_REMAINING -le 0 ] && [ "$SESSION_ACTIVE" = true ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ⏰ 连接超时，自动继续工作流"
    echo "═══════════════════════════════════════════════════════════"
    SESSION_ACTIVE=false
fi

# 清理
cleanup

echo ""
echo "🚀 继续执行后续步骤..."
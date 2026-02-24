#!/bin/bash
# .github/scripts/debug-ssh.sh
# GitHub Actions SSH 调试脚本

set -e

echo "🛠️ 正在设置 SSH 调试环境..."

TIMEOUT=1800        # 保持运行时间
CHECK_INTERVAL=30   # 检查间隔30秒
TIME_REMAINING=$TIMEOUT
SESSION_ACTIVE=true

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

# 发送通知（可选）
if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
  echo "发送 Telegram 通知..."
  curl --silent --output /dev/null \
  -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d chat_id="$TELEGRAM_CHAT_ID" \
  -d text="🖥️ SSH 调试会话已启动
  🔗 连接命令：
  ssh -o StrictHostKeyChecking=no $SSH_CMD
  ⏱️ 超时：30分钟
  📁 目录：$GITHUB_WORKSPACE"
  echo ""
fi

# 主循环
while [ $TIME_REMAINING -gt 0 ] && [ "$SESSION_ACTIVE" = true ]; do
    MINUTES=$((TIME_REMAINING / 60))
    SECONDS=$((TIME_REMAINING % 60))
    
    # 检查会话是否还存在
    if ! tmate -S "$TMATE_SOCK" has-session -t "$SESSION_ID" 2>/dev/null; then
        echo "❌ SSH 会话已结束"
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
    echo "  📋 可用命令:"
    echo "    • cd openwrt      - 进入项目目录"
    echo "    • make menuconfig - 开始配置软件包"
    echo "    • exit            - 退出并继续工作流"
    echo "    • Ctrl+D          - 快速退出"
    echo "    • pwd             - 查看当前目录"
    echo "    • ls -la          - 查看文件列表"
    echo ""
    echo "  ⏰ 剩余时间: ${MINUTES}分${SECONDS}秒"
    echo ""
    echo "用终端连接SSH，然后以[q]或[ctrl+c]开始和[ctrl+d]结束"
    echo "想要快速跳过此步骤，只需连接SSH并退出即可"
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
fi

# 清理
if [ "$SESSION_ACTIVE" = true ]; then
    echo "❌ 正在关闭 SSH 会话..."
    tmate -S "$TMATE_SOCK" kill-server 2>/dev/null || true
    rm -f "$TMATE_SOCK"
fi

echo ""
echo "🚀 继续执行后续步骤..."
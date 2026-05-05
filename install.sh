#!/bin/bash

# ==========================================
# AI_Proxy_Tools 一键安装与快捷指令配置脚本
# ==========================================

set -e

echo "========================================================"
echo "          🚀 正在安装 AI Proxy Tools 聚合运维套件        "
echo "========================================================"

if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 本套件涉及系统级操作，请使用管理员权限(sudo)运行！"
    echo "💡 示例: curl -sL https://raw.githubusercontent.com/qiqi-style/AI_Proxy_Tools/main/install.sh | sudo bash"
    exit 1
fi

echo ">>> 正在检测并安装基础依赖 (git, curl, wget)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -qq >/dev/null 2>&1
    apt-get install -y -qq git curl wget >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q git curl wget >/dev/null 2>&1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "❌ 错误: Git 安装失败，请手动安装 git 后重试！"
    exit 1
fi

INSTALL_DIR="/opt/AI_Proxy_Tools"

if [ -d "$INSTALL_DIR" ]; then
    echo ">>> 检测到本地已存在 $INSTALL_DIR，正在同步最新代码..."
    cd "$INSTALL_DIR"
    git fetch --all >/dev/null 2>&1
    git reset --hard origin/main >/dev/null 2>&1
else
    echo ">>> 正在从 Github 克隆最新代码到 $INSTALL_DIR..."
    git clone https://github.com/qiqi-style/AI_Proxy_Tools.git "$INSTALL_DIR" >/dev/null 2>&1
fi

echo ">>> 正在配置可执行权限与快捷指令..."
chmod +x "$INSTALL_DIR"/*.sh

# 创建全局快捷指令包装器，避免由于工作目录导致的脚本相对路径错误
cat > /usr/local/bin/aitool << 'EOF'
#!/bin/bash
cd /opt/AI_Proxy_Tools && sudo ./start.sh
EOF
chmod +x /usr/local/bin/aitool

echo "========================================================"
echo "🎉 安装圆满完成！"
echo ""
echo "💡 超级便利提醒："
echo "以后无论你在服务器的任何目录，只需在终端输入: aitool"
echo "即可一键瞬间唤出 AI 聚合管理控制台！"
echo "========================================================"
echo "正在为您首次启动控制台..."
sleep 3

aitool < /dev/tty

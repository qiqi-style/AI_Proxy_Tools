#!/bin/bash
export LANG=en_US.UTF-8

# ==========================================
# AI_Proxy_Tools 一键安装与快捷指令配置脚本 - QIQI-STYLE
# ==========================================

set -e

# 颜色定义
pink_c='\033[38;5;211m'
green_c='\033[38;5;118m'
orange_c='\033[38;5;208m'
plain='\033[0m'

# 辅助函数
pink(){ printf "\033[38;5;211m%s\033[0m\n" "$1";}
green(){ printf "\033[38;5;118m%s\033[0m\n" "$1";}
yellow(){ printf "\033[38;5;208m%s\033[0m\n" "$1";}
red(){ printf "\033[38;5;211m%s\033[0m\n" "$1";}

echo -e "${pink_c}────────────────────────────────────────────────────────${plain}"
pink "          🚀 正在安装 AI Proxy Tools 聚合运维套件        "
echo -e "${pink_c}────────────────────────────────────────────────────────${plain}"

if [ "$EUID" -ne 0 ]; then
    red "❌ 错误: 本套件涉及系统级操作，请使用管理员权限(sudo)运行！"
    yellow "💡 示例: curl -sL https://raw.githubusercontent.com/qiqi-style/AI_Proxy_Tools/main/install.sh | sudo bash"
    exit 1
fi

pink ">>> 正在检测并安装基础依赖 (git, curl, wget)..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y -qq >/dev/null 2>&1
    apt-get install -y -qq git curl wget >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q git curl wget >/dev/null 2>&1
fi

if ! command -v git >/dev/null 2>&1; then
    red "❌ 错误: Git 安装失败，请手动安装 git 后重试！"
    exit 1
fi

INSTALL_DIR="/opt/AI_Proxy_Tools"

if [ -d "$INSTALL_DIR" ]; then
    pink ">>> 检测到本地已存在 $INSTALL_DIR，正在同步最新代码..."
    cd "$INSTALL_DIR"
    git fetch --all >/dev/null 2>&1
    git reset --hard origin/main >/dev/null 2>&1
else
    pink ">>> 正在从 Github 克隆最新代码到 $INSTALL_DIR..."
    git clone https://github.com/qiqi-style/AI_Proxy_Tools.git "$INSTALL_DIR" >/dev/null 2>&1
fi

pink ">>> 正在配置可执行权限与快捷指令..."
chmod +x "$INSTALL_DIR"/*.sh

# 创建全局快捷指令包装器
cat > /usr/local/bin/aitool << 'EOF'
#!/bin/bash
cd /opt/AI_Proxy_Tools && sudo ./start.sh
EOF
chmod +x /usr/local/bin/aitool

echo -e "${green_c}────────────────────────────────────────────────────────${plain}"
green "🎉 安装圆满完成！"
echo ""
green "💡 超级便利提醒："
green "以后无论你在服务器的任何目录，只需在终端输入: aitool"
green "即可一键瞬间唤出 AI 聚合管理控制台！"
echo -e "${green_c}────────────────────────────────────────────────────────${plain}"
pink "正在为您首次启动控制台..."
sleep 2

aitool < /dev/tty


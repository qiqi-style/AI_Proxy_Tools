#!/bin/bash

# ==========================================
# AITool 聚合管理控制台 (主菜单)
# ==========================================

# 获取当前脚本所在目录
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确保脚本以 root 权限运行，防止文件复制和 Docker 操作报错
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误: 本控制台涉及到系统目录的读写以及 Docker 操作，必须使用管理员权限运行！"
    echo "💡 提示: 请执行命令 \`sudo ./start.sh\`"
    exit 1
fi

# 依赖检测函数
check_env() {
    local missing=0
    echo "================================================================="
    echo "正在检测运行环境..."
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ 未检测到 Docker！"
        missing=1
    else
        echo "✅ Docker 已安装"
    fi
    
    if ! command -v nginx >/dev/null 2>&1; then
        echo "❌ 未检测到 Nginx！"
        missing=1
    else
        echo "✅ Nginx 已安装"
    fi
    
    if [ $missing -eq 1 ]; then
        echo "-----------------------------------------------------------------"
        echo "❌ 致命错误: 必须安装上述缺失的核心环境 (Docker / Nginx) 才能启动控制台！"
        echo "💡 提示: 请先在服务器上安装缺失的依赖，然后再重新运行此脚本。"
        echo "-----------------------------------------------------------------"
        echo ""
        exit 1
    else
        echo "✅ 运行环境检查通过！"
        sleep 1
    fi
}

# 初次启动时检测一次
check_env

while true; do
    clear
    echo "================================================================="
    echo "                  🤖 AITool 聚合管理控制台"
    echo "================================================================="
    echo " 项目简介："
    echo " 本项目是一个集成化的 AI 工具部署与运维套件。主要用于在服务器上"
    echo " 实现 AI 服务的一键安装、自动化更新、数据备份以及安全卸载。"
    echo ""
    echo " 包含模块："
    echo "  1. new-api     : 强大的 API 分发与管理系统"
    echo "  2. cli-proxy   : CPA 代理系统"
    echo "  3. chatgpt2api : 接口转换与图像生成服务"
    echo "================================================================="
    echo ""
    echo " 请选择你要进入的子系统："
    echo "  1. 📦 进入【安装与卸载管理】 (首次部署或彻底删除服务)"
    echo "  2. 🔄 进入【更新与备份管理】 (版本升级与数据备份)"
    echo "  3. 🌐 部署【Nginx 反代配置】 (自动复制并应用 Nginx 配置)"
    echo "  0. 退出控制台"
    echo ""
    read -p " 请输入选项 [0-3]: " choice
    
    case $choice in
        1)
            # 确保全局部署目录 /app 存在
            if [ ! -d "/app" ]; then
                echo ">>> 检测到不存在 /app 目录，正在请求权限为您自动创建..."
                sudo mkdir -p /app
                sudo chmod 777 /app
                echo "✅ /app 目录创建成功！"
            fi
            
            if [ -f "$BASE_DIR/install_docker.sh" ]; then
                chmod +x "$BASE_DIR/install_docker.sh"
                "$BASE_DIR/install_docker.sh"
            else
                echo "❌ 错误: 找不到 install_docker.sh 脚本！"
                sleep 2
            fi
            ;;
        2)
            if [ -f "$BASE_DIR/update_docker.sh" ]; then
                chmod +x "$BASE_DIR/update_docker.sh"
                "$BASE_DIR/update_docker.sh"
            else
                echo "❌ 错误: 找不到 update_docker.sh 脚本！"
                sleep 2
            fi
            ;;
        3)
            if [ -f "$BASE_DIR/nginx_conf_copy.sh" ]; then
                chmod +x "$BASE_DIR/nginx_conf_copy.sh"
                "$BASE_DIR/nginx_conf_copy.sh"
            else
                echo "❌ 错误: 找不到 nginx_conf_copy.sh 脚本！"
                sleep 2
            fi
            ;;
        0)
            echo "👋 已退出 AITool 管理控制台。"
            exit 0
            ;;
        *)
            echo "❌ 无效的选项，请重新输入。"
            sleep 1
            ;;
    esac
done

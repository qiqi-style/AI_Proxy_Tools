#!/bin/bash

# ==========================================
# Docker 项目一键初始安装脚本
# ==========================================

# 目录定义
# 获取当前脚本所在目录作为源文件初始目录
SOURCE_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 目标安装目录
TARGET_BASE_DIR="/app"

# 项目配置定义
# 格式: 名称|功能简写|Github仓库|内网测试URL
PROJECTS=(
    "new-api|API分发|QuantumNous/new-api|http://127.0.0.1:3000"
    "cli-proxy|cpa反代|router-for-me/CLIProxyAPI|http://127.0.0.1:8317/management.html"
    "chatgpt2api|图片生成|basketikun/chatgpt2api|http://127.0.0.1:13080"
)

# 获取GitHub最新Release Tag的函数
get_latest_version() {
    local repo=$1
    local version=$(curl -s --connect-timeout 5 "https://api.github.com/repos/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$version" ]; then
        echo "获取失败"
    else
        echo "$version"
    fi
}

# 检查URL连通性的函数
check_url() {
    local url=$1
    if curl -s --connect-timeout 3 "$url" >/dev/null; then
        echo -e "\033[32m[连通]\033[0m"
    else
        echo -e "\033[31m[不可达]\033[0m"
    fi
}

# 显示所有项目状态
show_status() {
    echo "================================================ 项目安装状态 ================================================"
    
    for i in "${!PROJECTS[@]}"; do
        IFS='|' read -r name func repo local_url <<< "${PROJECTS[$i]}"
        
        local target_path="$TARGET_BASE_DIR/$name"
        
        # 1. 检查安装状态 (通过判断目标目录是否有 docker-compose.yml)
        installed_info="\033[31m未安装\033[0m"
        if [ -f "$target_path/docker-compose.yml" ]; then
            installed_info="\033[32m已安装\033[0m"
        fi
        
        # 2. 获取Github最新版本
        latest_version=$(get_latest_version "$repo")
        eval "${name//-/_}_latest_version=\"\$latest_version\""
        
        # 3. 内网连通性及Nginx反代提示
        local_status=$(check_url "$local_url")
        local_msg="$local_status $local_url"
        
        # 如果内网连通，必须给出 Nginx 反代提示
        if [[ "$local_status" == *连通* ]]; then
            local_msg="$local_msg \033[33m(⚠️ 必须配置 Nginx 反代才可外网安全访问)\033[0m"
        fi
        
        # 打印展示
        echo -e "[\033[1;36m${name}\033[0m] - \033[1;35m${func}\033[0m"
        echo -e "  - 官方地址 : https://github.com/$repo"
        echo -e "  - 最新版本 : \033[33m$latest_version\033[0m"
        echo -e "  - 安装状态 : $installed_info"
        echo -e "  - 内网状态 : $local_msg"
        echo -e "  - 默认密码 : \033[1;32m123456\033[0m"
        echo "----------------------------------------------------------------------------------------------------------"
    done
}

# 安装具体项目的函数
install_project() {
    local index=$1
    IFS='|' read -r name func repo local_url <<< "${PROJECTS[$index]}"
    
    local target_path="$TARGET_BASE_DIR/$name"
    local source_path="$SOURCE_BASE_DIR/$name"
    
    local latest_var="${name//-/_}_latest_version"
    local latest_version="${!latest_var}"
    
    echo ""
    echo "----------------------------------------------------"
    echo ">> 正在准备检查并安装项目: $name"
    
    if [ -f "$target_path/docker-compose.yml" ]; then
        echo "提示: 项目 $name 已经安装在 $target_path，无须重复安装！"
        return
    fi
    
    if [ ! -d "$source_path" ]; then
        echo "错误: 在源目录 ($source_path) 中找不到初始文件，无法进行安装！"
        return
    fi
    
    echo "正在将 $name 初始文件复制到目标目录 $target_path ..."
    mkdir -p "$target_path"
    cp -a "$source_path/." "$target_path/"
    
    # 将最新版本号记录下来
    if [ "$latest_version" != "获取失败" ] && [ -n "$latest_version" ]; then
        echo "$latest_version" > "$target_path/version.txt"
    fi
    
    # 强制保证项目根目录中拥有 config.json 文件 (如果没有则生成空配置)
    if [ ! -f "$target_path/config.json" ]; then
        echo "{}" > "$target_path/config.json"
    fi
    
    echo "进入项目目录并执行 docker compose up -d 安装服务..."
    cd "$target_path" || return
    docker compose up -d
    
    echo "========================================"
    echo "项目 $name 安装操作执行完成！"
    echo "========================================"
    
    echo "正在测试内网连通性 (等待3秒)..."
    sleep 3
    local local_status=$(check_url "$local_url")
    if [[ "$local_status" == *连通* ]]; then
        echo -e "测试结果: \033[32m内网已连通!\033[0m"
        echo -e "\033[1;33m⚠️【重要提示】: 内网已连通！必须要配置 Nginx 反向代理，才能将服务安全地暴露在公网供外部访问！\033[0m"
        echo -e "\033[1;32m🔑【密码提示】: 系统的默认密码为 123456，请登录后及时修改。\033[0m"
    else
        echo -e "测试结果: \033[31m内网暂未连通 (可能是 Docker 容器启动较慢，请稍后刷新状态重试)。\033[0m"
        echo -e "\033[1;32m🔑【密码提示】: 系统的默认密码为 123456，请登录后及时修改。\033[0m"
    fi
}

# 删除具体项目的函数
delete_project() {
    local index=$1
    IFS='|' read -r name func repo local_url <<< "${PROJECTS[$index]}"
    local target_path="$TARGET_BASE_DIR/$name"

    echo ""
    echo "----------------------------------------------------"
    echo ">> 正在准备检查并删除项目: $name"
    
    if [ ! -f "$target_path/docker-compose.yml" ]; then
        echo "提示: 项目 $name 似乎未安装，无法执行删除操作。"
        return
    fi
    
    while true; do
        echo ""
        echo "请选择对 $name 的删除方式:"
        echo "  1. 保留目录 (停止容器，删除容器和关联的 Docker 镜像)"
        echo "  2. 删除目录 (彻底删除容器、镜像及整个项目文件夹)"
        echo "  3. 返回上一级"
        echo ""
        read -p "请输入选项 [1-3]: " del_choice
        
        case $del_choice in
            1)
                echo ">>> 正在停止并删除容器及关联镜像..."
                cd "$target_path" || return
                if [ "$name" == "new-api" ]; then
                    read -p "⚠️ 是否同时删除数据库数据卷 (pg_data)? (注意：删除后数据将永久丢失!) [y/N]: " del_vol
                    if [[ "$del_vol" =~ ^[Yy]$ ]]; then
                        docker compose down --rmi all -v
                    else
                        docker compose down --rmi all
                    fi
                else
                    docker compose down --rmi all
                fi
                echo ">>> 项目 $name 容器与镜像已删除，目录 $target_path 已保留。"
                return
                ;;
            2)
                echo ">>> 正在停止并删除容器及关联镜像..."
                cd "$target_path" || return
                if [ "$name" == "new-api" ]; then
                    read -p "⚠️ 是否同时彻底删除数据库数据卷 (pg_data)? (注意：删除后数据将永久丢失!) [y/N]: " del_vol
                    if [[ "$del_vol" =~ ^[Yy]$ ]]; then
                        docker compose down --rmi all -v
                    else
                        docker compose down --rmi all
                    fi
                else
                    docker compose down --rmi all
                fi
                cd "$TARGET_BASE_DIR" || return
                echo ">>> 正在彻底删除项目目录 $target_path ..."
                rm -rf "$target_path"
                echo ">>> 项目 $name 已彻底删除。"
                return
                ;;
            3)
                echo ">>> 取消操作，返回上一级..."
                return
                ;;
            *)
                echo "无效选项，请重新输入。"
                ;;
        esac
    done
}

# 主程序入口
while true; do
    clear
    echo "正在获取各个项目的安装状态与最新版本信息，请稍候..."
    echo ""
    show_status
    
    echo ""
    echo "请选择要执行的操作:"
    echo "  1. 安装 new-api"
    echo "  2. 安装 cli-proxy"
    echo "  3. 安装 chatgpt2api"
    echo "  4. 安装 全部项目"
    echo "  5. 删除 new-api"
    echo "  6. 删除 cli-proxy"
    echo "  7. 删除 chatgpt2api"
    echo "  0. 返回主菜单 (start.sh) / 退出"
    echo ""
    read -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1)
            install_project 0
            read -p "按回车键继续..."
            ;;
        2)
            install_project 1
            read -p "按回车键继续..."
            ;;
        3)
            install_project 2
            read -p "按回车键继续..."
            ;;
        4)
            install_project 0
            install_project 1
            install_project 2
            read -p "按回车键继续..."
            ;;
        5)
            delete_project 0
            read -p "按回车键继续..."
            ;;
        6)
            delete_project 1
            read -p "按回车键继续..."
            ;;
        7)
            delete_project 2
            read -p "按回车键继续..."
            ;;
        0)
            echo "即将返回主菜单或退出..."
            sleep 1
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入。"
            sleep 2
            ;;
    esac
done

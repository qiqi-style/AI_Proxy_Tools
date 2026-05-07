#!/bin/bash
export LANG=en_US.UTF-8

# ==========================================
# Docker 项目一键初始安装脚本 - QIQI-STYLE
# ==========================================

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
readp(){ IFS='' read -r -p "$(echo -e "\033[38;5;211m$1\033[0m")" $2 < /dev/tty;}

# 目录定义
SOURCE_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BASE_DIR="/app"

# 项目配置定义
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
        echo -e "\033[38;5;118m[连通]\033[0m"
    else
        echo -e "\033[38;5;211m[不可达]\033[0m"
    fi
}

# 显示所有项目状态
show_status() {
    echo -e "${pink_c}─────────────────────────── 项目安装状态 ─────────────────────────────${plain}"
    
    for i in "${!PROJECTS[@]}"; do
        IFS='|' read -r name func repo local_url <<< "${PROJECTS[$i]}"
        
        local target_path="$TARGET_BASE_DIR/$name"
        
        # 1. 检查安装状态
        installed_info="\033[38;5;211m未安装\033[0m"
        if [ -f "$target_path/docker-compose.yml" ]; then
            installed_info="\033[38;5;118m已安装\033[0m"
        fi
        
        # 2. 获取Github最新版本
        latest_version=$(get_latest_version "$repo")
        eval "${name//-/_}_latest_version=\"\$latest_version\""
        
        # 3. 内网连通性
        local_status=$(check_url "$local_url")
        local_msg="$local_status $local_url"
        
        if [[ "$local_status" == *连通* ]]; then
            local_msg="$local_msg \033[38;5;208m(⚠️ 建议配置 Nginx 反代)\033[0m"
        fi
        
        # 打印展示
        echo -e "  \033[38;5;118m⬥\033[0m \033[1;36m${name}\033[0m [\033[1;35m${func}\033[0m]"
        echo -e "    - 最新版本 : \033[38;5;208m$latest_version\033[0m"
        echo -e "    - 安装状态 : $installed_info"
        echo -e "    - 内网状态 : $local_msg"
        echo -e "    - 默认密码 : \033[38;5;118m123456\033[0m"
        echo -e "${pink_c}──────────────────────────────────────────────────────────────────────${plain}"
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
    
    echo
    pink ">> 正在准备检查并安装项目: $name"
    
    if [ -f "$target_path/docker-compose.yml" ]; then
        yellow "提示: 项目 $name 已经安装在 $target_path，无须重复安装！"
        return
    fi
    
    if [ ! -d "$source_path" ]; then
        red "错误: 在源目录 ($source_path) 中找不到初始文件，无法进行安装！"
        return
    fi
    
    pink "正在将 $name 初始文件复制到目标目录 $target_path ..."
    mkdir -p "$target_path"
    cp -a "$source_path/." "$target_path/"
    
    if [ "$latest_version" != "获取失败" ] && [ -n "$latest_version" ]; then
        echo "$latest_version" > "$target_path/version.txt"
    fi
    
    if [ ! -f "$target_path/config.json" ]; then
        echo "{}" > "$target_path/config.json"
    fi
    
    pink "进入项目目录并执行 docker compose up -d 安装服务..."
    cd "$target_path" || return
    docker compose up -d
    
    echo -e "${green_c}────────────────────────────────────────${plain}"
    green "项目 $name 安装操作执行完成！"
    echo -e "${green_c}────────────────────────────────────────${plain}"
    
    pink "正在测试内网连通性 (等待3秒)..."
    sleep 3
    local local_status=$(check_url "$local_url")
    if [[ "$local_status" == *连通* ]]; then
        green "测试结果: 内网已连通!"
        yellow "⚠️【重要提示】: 内网已连通！必须要配置 Nginx 反向代理，才能将服务安全地暴露在公网供外部访问！"
        green "🔑【密码提示】: 系统的默认密码为 123456，请登录后及时修改。"
    else
        red "测试结果: 内网暂未连通 (可能是 Docker 容器启动较慢)。"
        green "🔑【密码提示】: 系统的默认密码为 123456，请登录后及时修改。"
    fi
}

# 删除具体项目的函数
delete_project() {
    local index=$1
    IFS='|' read -r name func repo local_url <<< "${PROJECTS[$index]}"
    local target_path="$TARGET_BASE_DIR/$name"

    echo
    red ">> 正在准备检查并删除项目: $name"
    
    if [ ! -f "$target_path/docker-compose.yml" ]; then
        yellow "提示: 项目 $name 似乎未安装，无法执行删除操作。"
        return
    fi
    
    while true; do
        echo
        echo -e "  请选择对 \033[1;36m$name\033[0m 的删除方式:"
        echo -e "  \033[38;5;118m[ 1 ]\033[0m 保留目录 (停止容器，删除容器和关联的 Docker 镜像)"
        echo -e "  \033[38;5;118m[ 2 ]\033[0m 删除目录 (彻底删除容器、镜像及整个项目文件夹)"
        echo -e "  \033[38;5;245m[ 3 ]\033[0m 返回上一级"
        echo
        readp "  请输入选项数字 [1-3] → " del_choice
        
        case $del_choice in
            1)
                pink ">>> 正在停止并删除容器及关联镜像..."
                cd "$target_path" || return
                if [ "$name" == "new-api" ]; then
                    readp "⚠️ 是否同时删除数据库数据卷 (pg_data)? [y/N] → " del_vol
                    if [[ "$del_vol" =~ ^[Yy]$ ]]; then
                        docker compose down --rmi all -v
                    else
                        docker compose down --rmi all
                    fi
                else
                    docker compose down --rmi all
                fi
                green ">>> 项目 $name 容器与镜像已删除，目录 $target_path 已保留。"
                return
                ;;
            2)
                pink ">>> 正在停止并删除容器及关联镜像..."
                cd "$target_path" || return
                if [ "$name" == "new-api" ]; then
                    readp "⚠️ 是否同时彻底删除数据库数据卷 (pg_data)? [y/N] → " del_vol
                    if [[ "$del_vol" =~ ^[Yy]$ ]]; then
                        docker compose down --rmi all -v
                    else
                        docker compose down --rmi all
                    fi
                else
                    docker compose down --rmi all
                fi
                cd "$TARGET_BASE_DIR" || return
                pink ">>> 正在彻底删除项目目录 $target_path ..."
                rm -rf "$target_path"
                green ">>> 项目 $name 已彻底删除。"
                return
                ;;
            3)
                pink ">>> 取消操作，返回上一级..."
                return
                ;;
            *)
                red "无效选项，请重新输入。"
                ;;
        esac
    done
}

# 主程序入口
while true; do
    clear
    pink "正在获取各个项目的安装状态与最新版本信息，请稍候..."
    echo
    show_status
    
    echo
    echo -e "  \033[38;5;211m───────────────────── 模块管理菜单 ─────────────────────\033[0m"
    echo -e "  \033[38;5;118m[ 1 ]\033[0m 安装 \033[1;36mnew-api\033[0m"
    echo -e "  \033[38;5;118m[ 2 ]\033[0m 安装 \033[1;36mcli-proxy\033[0m"
    echo -e "  \033[38;5;118m[ 3 ]\033[0m 安装 \033[1;36mchatgpt2api\033[0m"
    echo -e "  \033[38;5;118m[ 4 ]\033[0m 安装 \033[38;5;208m全部项目\033[0m"
    echo -e "  \033[38;5;211m[ 5 ]\033[0m 删除 \033[1;36mnew-api\033[0m"
    echo -e "  \033[38;5;211m[ 6 ]\033[0m 删除 \033[1;36mcli-proxy\033[0m"
    echo -e "  \033[38;5;211m[ 7 ]\033[0m 删除 \033[1;36mchatgpt2api\033[0m"
    echo -e "  \033[38;5;245m[ 0 ]\033[0m 返回主菜单 (start.sh)"
    echo
    readp "  请输入选项数字 [0-7] → " choice
    
    case $choice in
        1) install_project 0; readp "按回车键继续..." dummy;;
        2) install_project 1; readp "按回车键继续..." dummy;;
        3) install_project 2; readp "按回车键继续..." dummy;;
        4)
            install_project 0
            install_project 1
            install_project 2
            readp "按回车键继续..." dummy
            ;;
        5) delete_project 0; readp "按回车键继续..." dummy;;
        6) delete_project 1; readp "按回车键继续..." dummy;;
        7) delete_project 2; readp "按回车键继续..." dummy;;
        0)
            pink "即将返回主菜单..."
            sleep 1
            exit 0
            ;;
        *)
            red "无效的选项，请重新输入。"
            sleep 2
            ;;
    esac
done


#!/bin/bash

# ==========================================
# Docker 项目一键更新及备份脚本
# ==========================================

# 获取当前脚本所在目录作为基础目录
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BASE_DIR="/app"

# 全局备份目录
BACKUP_DIR="$TARGET_BASE_DIR/backup"

# 项目配置定义
# 格式: 名称|功能简写|目录路径|Github仓库|内网测试URL|外网测试URL
PROJECTS=(
    "new-api|API分发|$TARGET_BASE_DIR/new-api|QuantumNous/new-api|http://127.0.0.1:3000|https://qiai.eu.cc"
    "cli-proxy|cpa反代|$TARGET_BASE_DIR/cli-proxy|router-for-me/CLIProxyAPI|http://127.0.0.1:8317/management.html|https://cpa.qiai.eu.cc/management.html"
    "chatgpt2api|图片生成|$TARGET_BASE_DIR/chatgpt2api|basketikun/chatgpt2api|http://127.0.0.1:13080|https://img.qiai.eu.cc"
)

# 获取GitHub最新Release Tag的函数
get_latest_version() {
    local repo=$1
    # 尝试获取 latest release 的 tag_name
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
    # curl 发送请求，无论 HTTP 状态码是多少，只要能连接且收到响应就是连通的
    if curl -s --connect-timeout 3 "$url" >/dev/null; then
        echo -e "\033[32m[连通]\033[0m"
    else
        echo -e "\033[31m[不可达]\033[0m"
    fi
}

# 获取 Nginx 目录用于解析外网域名
NGINX_DIR=""
if command -v nginx >/dev/null 2>&1; then
    # 方法1: 通过 nginx -t 提取正在使用的配置 (最准确)
    NGINX_CONF_PATH=$(nginx -t 2>&1 | grep "configuration file " | head -n 1 | awk -F 'configuration file ' '{print $2}' | awk '{print $1}')
    
    # 方法2: 如果出错，通过 nginx -V 提取编译参数
    if [ -z "$NGINX_CONF_PATH" ] || [ ! -f "$NGINX_CONF_PATH" ]; then
        NGINX_CONF_PATH=$(nginx -V 2>&1 | grep -o -E '\-\-conf-path=[^ ]+' | cut -d '=' -f 2)
    fi
    
    if [ -n "$NGINX_CONF_PATH" ] && [ -f "$NGINX_CONF_PATH" ]; then
        NGINX_DIR=$(dirname "$NGINX_CONF_PATH")
    fi
fi

if [ -z "$NGINX_DIR" ] || [ ! -d "$NGINX_DIR" ]; then
    for p in "/etc/nginx" "/usr/local/nginx/conf" "/opt/homebrew/etc/nginx"; do
        if [ -d "$p" ]; then NGINX_DIR="$p"; break; fi
    done
fi

# 显示所有项目状态
show_status() {
    echo "================================================ 项目状态 ================================================"
    
    for i in "${!PROJECTS[@]}"; do
        IFS='|' read -r name func path repo local_url fallback_public_url <<< "${PROJECTS[$i]}"
        
        # 解析外网地址 (从 Nginx 配置)
        public_url="未配置"
        if [ -n "$NGINX_DIR" ] && [ -f "$NGINX_DIR/conf.d/${name}.conf" ]; then
            domain=$(grep -m 1 "server_name" "$NGINX_DIR/conf.d/${name}.conf" | awk '{print $2}' | tr -d ';')
            ext_port=$(grep -m 1 "listen " "$NGINX_DIR/conf.d/${name}.conf" | grep -o -E '[0-9]+' | head -n 1)
            
            if [ -n "$domain" ] && [[ "$domain" != *"your_domain"* ]]; then
                port_suffix=""
                if [ -n "$ext_port" ] && [ "$ext_port" != "443" ] && [ "$ext_port" != "80" ]; then
                    port_suffix=":$ext_port"
                fi
                
                if [ "$name" == "cli-proxy" ]; then
                    public_url="https://$domain$port_suffix/management.html"
                else
                    public_url="https://$domain$port_suffix"
                fi
            fi
        fi
        
        # 1. 检查安装状态、容器名称和ID
        installed_info="\033[31m未安装\033[0m"
        if [ -f "$path/docker-compose.yml" ]; then
            installed_info="\033[32m已安装\033[0m"
            
            # 获取容器信息 (名称和ID)
            if [ -d "$path" ]; then
                # 使用 docker compose ps 获取容器名称和短ID，以逗号分隔
                containers_info=$(cd "$path" 2>/dev/null && docker compose ps --format '{{.Name}} (ID: {{.ID}})' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
                if [ -n "$containers_info" ]; then
                    installed_info="$installed_info | 容器: $containers_info"
                else
                    installed_info="$installed_info | 容器未运行"
                fi
            fi
        fi
        
        # 2. 获取当前版本
        current_version="未知"
        if [ -f "$path/version.txt" ]; then
            current_version=$(cat "$path/version.txt")
        elif [ -f "$path/vertion.txt" ]; then
            current_version=$(cat "$path/vertion.txt")
        fi
        
        # 3. 内外网连通性
        local_status=$(check_url "$local_url")
        if [[ "$public_url" == http* ]]; then
            public_status=$(check_url "$public_url")
        else
            public_status="\033[33m[未配置]\033[0m"
        fi
        
        # 4. Github最新版本
        latest_version=$(get_latest_version "$repo")
        
        # 动态变量保存版本供后续使用
        eval "${name//-/_}_latest_version=\"\$latest_version\""
        eval "${name//-/_}_current_version=\"\$current_version\""
        
        # 打印展示
        echo -e "[\033[1;36m${name}\033[0m] - \033[1;35m${func}\033[0m"
        echo -e "  - 官方地址 : https://github.com/$repo"
        echo -e "  - 安装状态 : $installed_info"
        echo -e "  - 内网状态 : $local_status $local_url"
        echo -e "  - 外网状态 : $public_status $public_url"
        echo -e "  - 项目版本 : 当前版本 \033[33m$current_version\033[0m | 最新版本 \033[33m$latest_version\033[0m"
        echo "----------------------------------------------------------------------------------------------------------"
    done
}

# 更新具体项目的函数
update_project() {
    local index=$1
    IFS='|' read -r name func path repo local_url public_url <<< "${PROJECTS[$index]}"
    
    local latest_var="${name//-/_}_latest_version"
    local current_var="${name//-/_}_current_version"
    local latest_version="${!latest_var}"
    local current_version="${!current_var}"
    
    echo ""
    echo "----------------------------------------------------"
    echo ">> 正在准备检查/更新项目: $name"
    
    if [ ! -d "$path" ]; then
        echo "错误: 项目目录 $path 不存在，无法更新!"
        return
    fi
    
    if [ ! -f "$path/docker-compose.yml" ]; then
        echo "错误: 项目目录 $path 中未找到 docker-compose.yml!"
        return
    fi
    
    if [ "$latest_version" == "获取失败" ] || [ -z "$latest_version" ]; then
        echo "警告: 无法获取最新版本，跳过更新!"
        return
    fi
    
    if [ "$current_version" == "$latest_version" ]; then
        echo "提示: 项目 $name 已是最新版本 ($current_version)。"
        while true; do
            echo ""
            echo "请选择操作:"
            echo "  1. 重新安装 (强制拉取镜像并重启)"
            echo "  2. 返回上一级"
            read -p "请输入选项 [1-2]: " sub_choice
            case $sub_choice in
                1)
                    echo ">>> 正在重新安装 $name ..."
                    cd "$path" || return
                    docker compose pull
                    docker compose down
                    docker compose up -d
                    docker image prune -f
                    echo "========================================"
                    echo "项目 $name 重新安装完成！"
                    echo "========================================"
                    return
                    ;;
                2)
                    return
                    ;;
                *)
                    echo "无效选项，请重新输入。"
                    ;;
            esac
        done
    fi
    
    echo "发现新版本: $current_version -> $latest_version，开始更新流程..."
    
    # 1. 创建备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "创建备份目录: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # 2. 压缩备份项目
    local timestamp=$(date +"%Y%m%d")
    local backup_file="$BACKUP_DIR/${name}-${timestamp}.tar.gz"
    echo "正在备份 $name 到 $backup_file ..."
    tar -zcf "$backup_file" -C $(dirname "$path") $(basename "$path")
    if [ $? -eq 0 ]; then
        echo "备份成功!"
    else
        echo "错误: 备份失败，终止更新!"
        return
    fi
    
    # 3. 清理旧备份 (仅保留最近3个)
    echo "清理旧备份 (仅保留最近3个)..."
    local backups=($(ls -t "$BACKUP_DIR"/${name}-*.tar.gz 2>/dev/null))
    if [ ${#backups[@]} -gt 3 ]; then
        for ((i=3; i<${#backups[@]}; i++)); do
            echo "删除旧备份: ${backups[$i]}"
            rm -f "${backups[$i]}"
        done
    fi
    
    # 4. 更新版本记录文件 (创建 version.txt)
    echo "$latest_version" > "$path/version.txt"
    # 如果存在旧的拼写错误的文件，顺便删除它
    [ -f "$path/vertion.txt" ] && rm -f "$path/vertion.txt"
    
    # 5. 更新 docker compose
    echo "进入项目目录 $path 并执行 docker compose 更新..."
    cd "$path" || return
    
    echo ">>> 执行: docker compose pull"
    docker compose pull
    
    echo ">>> 执行: docker compose up -d"
    docker compose up -d
    
    echo ">>> 执行: docker image prune -f"
    docker image prune -f
    
    echo "========================================"
    echo "项目 $name 更新完成！"
    echo "========================================"
    
    # 更新当前内存中的版本变量，以便如果连续不退出查看时显示正确
    eval "${name//-/_}_current_version=\"\$latest_version\""
}

# 主程序入口
while true; do
    clear
    echo "正在获取各个项目的运行状态与版本信息，请稍候..."
    echo ""
    show_status
    
    echo ""
    echo "请选择要执行的操作:"
    echo "  1. 更新 new-api"
    echo "  2. 更新 cli-proxy"
    echo "  3. 更新 chatgpt2api"
    echo "  4. 更新 全部项目"
    echo "  0. 返回主菜单 (start.sh) / 退出"
    echo ""
    read -p "请输入选项 [0-4]: " choice
    
    case $choice in
        1)
            update_project 0
            read -p "按回车键继续..."
            ;;
        2)
            update_project 1
            read -p "按回车键继续..."
            ;;
        3)
            update_project 2
            read -p "按回车键继续..."
            ;;
        4)
            update_project 0
            update_project 1
            update_project 2
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

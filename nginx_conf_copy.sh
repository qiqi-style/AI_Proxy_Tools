#!/bin/bash

# ==========================================
# Nginx 配置文件按需生成与自动部署脚本
# ==========================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BASE_DIR="/app"

# 检查项目是否已安装 (通过 docker-compose.yml)
check_installed() {
    local project=$1
    if [ -f "$TARGET_BASE_DIR/$project/docker-compose.yml" ]; then
        return 0
    else
        return 1
    fi
}

# 全局执行一次：自动搜寻 Nginx 配置文件目录
NGINX_DIR=""
NGINX_CONF_PATH=""
if command -v nginx >/dev/null 2>&1; then
    # 优先通过 nginx -t 提取正在使用的配置
    NGINX_CONF_PATH=$(nginx -t 2>&1 | grep "configuration file " | head -n 1 | awk -F 'configuration file ' '{print $2}' | awk '{print $1}')
    if [ -z "$NGINX_CONF_PATH" ] || [ ! -f "$NGINX_CONF_PATH" ]; then
        NGINX_CONF_PATH=$(nginx -V 2>&1 | grep -o -E '\-\-conf-path=[^ ]+' | cut -d '=' -f 2)
    fi
fi

if [ -z "$NGINX_CONF_PATH" ] || [ ! -f "$NGINX_CONF_PATH" ]; then
    for p in "/etc/nginx/nginx.conf" "/usr/local/nginx/conf/nginx.conf" "/opt/homebrew/etc/nginx/nginx.conf"; do
        if [ -f "$p" ]; then NGINX_CONF_PATH="$p"; break; fi
    done
fi

if [ -n "$NGINX_CONF_PATH" ] && [ -f "$NGINX_CONF_PATH" ]; then
    NGINX_DIR=$(dirname "$NGINX_CONF_PATH")
fi

# 自动修正路径 (针对 /conf 子目录)
if [ -n "$NGINX_DIR" ]; then
    if [ -d "$NGINX_DIR/conf" ] && [ -f "$NGINX_DIR/conf/nginx.conf" ]; then
        NGINX_DIR="$NGINX_DIR/conf"
    elif [ -d "$NGINX_DIR/conf" ] && [ ! -f "$NGINX_DIR/nginx.conf" ]; then
        NGINX_DIR="$NGINX_DIR/conf"
    fi
fi

# 自动重载 Nginx 辅助函数
reload_nginx() {
    echo ""
    echo ">>> 正在检测 Nginx 语法..."
    if nginx -t; then
        echo ">>> 正在重载 Nginx 配置..."
        if nginx -s reload; then
            echo "✅ Nginx 配置已成功生效！"
        else
            echo "❌ Nginx 重载失败，请检查上方报错！"
        fi
    else
        echo "❌ Nginx 语法检测未通过，重载已被取消！"
        echo "⚠️ 提示: 请根据上方的报错信息，检查证书文件路径或配置内容是否有误。"
    fi
}

# 获取项目 Nginx 代理状态及外网地址
get_nginx_info() {
    local pname=$1
    local pconf="$NGINX_DIR/conf.d/${pname}.conf"
    if [ -n "$NGINX_DIR" ] && [ -f "$pconf" ]; then
        local domain=$(grep -m 1 "server_name" "$pconf" | awk '{print $2}' | tr -d ';')
        local ext_port=$(grep -m 1 "listen " "$pconf" | grep -o -E '[0-9]+' | head -n 1)
        if [ -n "$domain" ] && [[ "$domain" != *"your_domain"* ]]; then
            local port_suffix=""
            if [ -n "$ext_port" ] && [ "$ext_port" != "443" ] && [ "$ext_port" != "80" ]; then
                port_suffix=":$ext_port"
            fi
            if [ "$pname" == "cli-proxy" ]; then
                echo -e "\033[32m已配置\033[0m (https://$domain$port_suffix/management.html)"
            else
                echo -e "\033[32m已配置\033[0m (https://$domain$port_suffix)"
            fi
            return
        fi
    fi
    echo -e "\033[33m未配置\033[0m"
}

while true; do
    clear
    echo "================================================================="
    echo "                  🌐 Nginx 反向代理自动部署工具"
    echo "================================================================="
    
    # 获取各个项目安装状态
    status_new_api="\033[31m未安装\033[0m"
    status_cli_proxy="\033[31m未安装\033[0m"
    status_chatgpt2api="\033[31m未安装\033[0m"
    
    check_installed "new-api" && status_new_api="\033[32m已安装\033[0m"
    check_installed "cli-proxy" && status_cli_proxy="\033[32m已安装\033[0m"
    check_installed "chatgpt2api" && status_chatgpt2api="\033[32m已安装\033[0m"
    
    # 获取各个项目 Nginx 配置状态
    conf_new_api=$(get_nginx_info "new-api")
    conf_cli_proxy=$(get_nginx_info "cli-proxy")
    conf_chatgpt2api=$(get_nginx_info "chatgpt2api")
    
    echo -e " 1. 部署 \033[1;36mnew-api\033[0m       [$status_new_api] | Nginx: $conf_new_api"
    echo -e " 2. 部署 \033[1;36mcli-proxy\033[0m     [$status_cli_proxy] | Nginx: $conf_cli_proxy"
    echo -e " 3. 部署 \033[1;36mchatgpt2api\033[0m   [$status_chatgpt2api] | Nginx: $conf_chatgpt2api"
    echo " ----------------------------------------------------------------"
    echo -e " 4. 删除 \033[1;31mnew-api\033[0m       配置"
    echo -e " 5. 删除 \033[1;31mcli-proxy\033[0m     配置"
    echo -e " 6. 删除 \033[1;31mchatgpt2api\033[0m   配置"
    echo " ----------------------------------------------------------------"
    echo " 0. 返回主菜单"
    echo "================================================================="
    read -p " 请选择操作选项 [0-6]: " choice
    
    project=""
    conf_file=""
    default_port=""
    action=""
    
    case $choice in
        1) project="new-api"; conf_file="new-api.conf"; default_port="3000"; action="deploy" ;;
        2) project="cli-proxy"; conf_file="cli-proxy.conf"; default_port="8317"; action="deploy" ;;
        3) project="chatgpt2api"; conf_file="chatgpt2api.conf"; default_port="13080"; action="deploy" ;;
        4) project="new-api"; conf_file="new-api.conf"; action="delete" ;;
        5) project="cli-proxy"; conf_file="cli-proxy.conf"; action="delete" ;;
        6) project="chatgpt2api"; conf_file="chatgpt2api.conf"; action="delete" ;;
        0) echo "返回主菜单..."; exit 0 ;;
        *) echo "无效选项，请重新输入。"; sleep 1; continue ;;
    esac
    
    # 强制让用户提供 NGINX_DIR
    if [ -z "$NGINX_DIR" ] || [ ! -d "$NGINX_DIR" ]; then
        echo ""
        read -p "❌ 自动搜寻 Nginx 目录失败，请手动输入配置目录路径 (如 /etc/nginx): " NGINX_DIR
        # 手动输入后修正
        if [ -d "$NGINX_DIR/conf" ] && [ -f "$NGINX_DIR/conf/nginx.conf" ]; then
            NGINX_DIR="$NGINX_DIR/conf"
        elif [ -d "$NGINX_DIR/conf" ] && [ ! -f "$NGINX_DIR/nginx.conf" ]; then
            NGINX_DIR="$NGINX_DIR/conf"
        fi
    fi
    
    if [ ! -d "$NGINX_DIR" ]; then
        echo "❌ 该目录不存在: $NGINX_DIR"
        sleep 2
        continue
    fi
    
    if [ "$action" == "delete" ]; then
        echo ""
        echo "========================================================"
        if [ -f "$NGINX_DIR/conf.d/$conf_file" ]; then
            echo ">>> 找到配置: $NGINX_DIR/conf.d/$conf_file"
            read -p "⚠️ 确认要彻底删除 $project 的 Nginx 配置吗？[y/N]: " del_conf
            if [[ "$del_conf" =~ ^[Yy]$ ]]; then
                rm -f "$NGINX_DIR/conf.d/$conf_file"
                echo "✅ $project 的 Nginx 配置已彻底删除。"
                reload_nginx
            else
                echo "已取消删除操作。"
            fi
        else
            echo "提示: 未找到 $project 的相关配置，可能尚未部署。"
        fi
        echo "========================================================"
        read -p "按回车键返回菜单..."
        continue
    fi

    # 以下是部署 (deploy) 的专有逻辑
    if ! check_installed "$project"; then
        echo ""
        echo "⚠️ 警告: 检测到项目 $project 似乎未安装！"
        read -p "是否强制继续生成其 Nginx 配置？[y/N]: " force_cont
        if [[ ! "$force_cont" =~ ^[Yy]$ ]]; then
            continue
        fi
    fi
    
    # 提取当前已有的配置作为默认值
    current_domain=""
    current_port=$default_port
    current_ext_port="443"
    current_cert=""
    current_key=""
    
    pconf="$NGINX_DIR/conf.d/${conf_file}"
    if [ -f "$pconf" ]; then
        current_domain=$(grep -m 1 "server_name" "$pconf" | awk '{print $2}' | tr -d ';')
        extracted_port=$(grep -m 1 "proxy_pass" "$pconf" | grep -o -E '[0-9]+;' | tr -d ';')
        if [ -n "$extracted_port" ]; then current_port=$extracted_port; fi
        
        extracted_ext_port=$(grep -m 1 "listen " "$pconf" | grep -o -E '[0-9]+' | head -n 1)
        if [ -n "$extracted_ext_port" ]; then current_ext_port=$extracted_ext_port; fi
        
        current_cert=$(grep -m 1 "ssl_certificate " "$pconf" | awk '{print $2}' | tr -d ';')
        current_key=$(grep -m 1 "ssl_certificate_key" "$pconf" | awk '{print $2}' | tr -d ';')
        
        # 如果获取到的是模板里的占位符，清空它以便提示用户输入
        [[ "$current_domain" == *"your_domain"* ]] && current_domain=""
        [[ "$current_cert" == *"/path/to/"* ]] && current_cert=""
        [[ "$current_key" == *"/path/to/"* ]] && current_key=""
    fi

    echo ""
    echo "--------------------------------------------------------"
    echo ">>> 请输入 $project 的 Nginx 代理信息 <<<"
    echo "💡 提示: 中括号内为当前配置的【默认值】，若无需修改直接回车即可！"
    echo "--------------------------------------------------------"
    
    # 交互式输入，若留空则保留原来的值
    read -p "1. 绑定的公网域名 [当前: ${current_domain:-未配置}]: " domain
    domain=${domain:-$current_domain}
    
    read -p "2. 本地代理转发端口 (内部服务) [当前: ${current_port}]: " port
    port=${port:-$current_port}
    
    read -p "3. 外网访问监听端口 [当前: ${current_ext_port}]: " ext_port
    ext_port=${ext_port:-$current_ext_port}
    
    read -p "4. SSL证书文件(crt/pem)绝对路径 [当前: ${current_cert:-未配置}]: " ssl_cert
    ssl_cert=${ssl_cert:-$current_cert}
    
    read -p "5. SSL私钥文件(key)绝对路径 [当前: ${current_key:-未配置}]: " ssl_key
    ssl_key=${ssl_key:-$current_key}
    
    if [ -z "$domain" ] || [ -z "$ssl_cert" ] || [ -z "$ssl_key" ]; then
        echo "❌ 错误: 域名或证书路径不能为空，部署已取消！"
        sleep 2
        continue
    fi
    
    echo ">>> 正在生成自定义配置文件..."
    mkdir -p "$NGINX_DIR/conf.d"
    
    # 核心：使用 cat 和 sed 跨平台流式替换占位符文本，写入到最终目录
    cat "$BASE_DIR/nginx-config/conf.d/$conf_file" | \
    sed "s|your_domain.com|$domain|g" | \
    sed "s|/path/to/your/cert.crt|$ssl_cert|g" | \
    sed "s|/path/to/your/private.key|$ssl_key|g" | \
    sed "s|listen 443 |listen $ext_port |g" | \
    sed "s|127.0.0.1:$default_port|127.0.0.1:$port|g" > "$NGINX_DIR/conf.d/$conf_file"
    
    # 若外网端口不是 443，则自动删除末尾的 80 转 443 代码块
    if [ "$ext_port" != "443" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/# 80 转 443/,$d' "$NGINX_DIR/conf.d/$conf_file"
        else
            sed -i '/# 80 转 443/,$d' "$NGINX_DIR/conf.d/$conf_file"
        fi
    fi
    
    echo "✅ 配置文件已安全写入到: $NGINX_DIR/conf.d/$conf_file"
    
    # 检测主 nginx.conf 是否有 conf.d 引入
    if grep -q "conf\.d" "$NGINX_DIR/nginx.conf"; then
        echo "✅ 原 nginx.conf 已包含 conf.d 目录引入，无需额外修改。"
    else
        echo "⚠️ 原 nginx.conf 缺少 conf.d 引入语句，正在尝试自动注入..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/http[[:space:]]*{/a \
    include ./conf.d/*.conf;' "$NGINX_DIR/nginx.conf" 2>/dev/null
        else
            sed -i '/http[[:space:]]*{/a \    include ./conf.d/*.conf;' "$NGINX_DIR/nginx.conf" 2>/dev/null
        fi
        echo "✅ 注入完成！"
    fi
    
    echo "========================================================"
    echo "🎉 $project 配置文件处理完毕！"
    reload_nginx
    echo "========================================================"
    read -p "按回车键返回 Nginx 部署菜单..."
done

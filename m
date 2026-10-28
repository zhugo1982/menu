#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (sudo bash menu.sh)"
  exit 1
fi

CONF_FILE="/etc/nginx/conf.d/b.conf"
SCRIPT_PATH="/usr/local/bin/hgg-manager" # 脚本将安装到的系统路径

# 自动安装脚本到系统命令目录并配置快捷方式
setup_shortcut() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        # 将当前脚本复制到全局 bin 目录
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        
        echo "=========================================="
        read -p "请为该脚本设置一个顺手的快捷方式命令（例如输入 hgg 或 manager）: " shortcut_cmd
        if [ -n "$shortcut_cmd" ]; then
            # 写入 alias 到 bashrc
            echo "alias $shortcut_cmd='sudo $SCRIPT_PATH'" >> ~/.bashrc
            source ~/.bashrc
            echo "==> 快捷方式设置成功！"
            echo "==> 以后你只需要直接在终端输入: 【 $shortcut_cmd 】 即可随时打开此菜单！"
            echo "=========================================="
            sleep 2
        fi
    fi
}

# 首次运行自动触发配置快捷方式
setup_shortcut

show_menu() {
    clear
    echo "=========================================="
    echo "       Nginx 反向代理与域名管理菜单       "
    echo "=========================================="
    echo " 1. 安装 Nginx 并初始化反向代理配置"
    echo " 2. 修改 / 更改当前绑定的域名"
    echo " 3. 添加新域名"
    echo " 4. 删除/清空域名配置"
    echo " 5. 卸载 Nginx 及相关残留"
    echo " 0. 退出脚本"
    echo "=========================================="
    read -p "请输入选项 [0-5]: " choice
}

install_nginx() {
    echo "==> 正在更新系统并安装 Nginx..."
    apt update && apt install -y nginx
    
    cat > "$CONF_FILE" << 'EOF'
server {
    listen 80;
    server_name b.hgg.kdns.fr;

    location / {
        proxy_pass https://18.190.153.157:2096/admin;
        
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        
        proxy_redirect off;
        proxy_cookie_path / /;
        
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
EOF
    nginx -t && systemctl enable nginx && systemctl restart nginx
    echo "==> Nginx 安装与初始化配置完成！"
    read -p "按回车键继续..."
}

update_domain() {
    read -p "请输入新的主域名（多个域名请用空格隔开）: " new_domains
    if [ -z "$new_domains" ]; then
        echo "域名不能为空！"
        read -p "按回车键继续..."
        return
    fi
    
    if [ -f "$CONF_FILE" ]; then
        sed -i "s/server_name .*/server_name $new_domains;/" "$CONF_FILE"
        nginx -t && systemctl reload nginx
        echo "==> 域名已成功修改为: $new_domains"
    else
        echo "未找到配置文件，请先执行安装！"
    fi
    read -p "按回车键继续..."
}

add_domain() {
    read -p "请输入要追加的新域名: " add_dom
    if [ -z "$add_dom" ]; then
        echo "域名不能为空！"
        read -p "按回车键继续..."
        return
    fi
    
    if [ -f "$CONF_FILE" ]; then
        sed -i "/server_name/s/;/ $add_dom;/" "$CONF_FILE"
        nginx -t && systemctl reload nginx
        echo "==> 域名 $add_dom 添加成功！"
    else
        echo "未找到配置文件，请先执行安装！"
    fi
    read -p "按回车键继续..."
}

remove_domain() {
    read -p "请输入想要移除的域名: " rm_dom
    if [ -f "$CONF_FILE" ]; then
        sed -i "s/$rm_dom//g" "$CONF_FILE"
        nginx -t && systemctl reload nginx
        echo "==> 域名 $rm_dom 已尝试从配置中移除。"
    else
        echo "未找到配置文件！"
    fi
    read -p "按回车键继续..."
}

uninstall_nginx() {
    read -p "确定要完全卸载 Nginx 及其配置文件吗？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        systemctl stop nginx
        apt purge -y nginx nginx-common nginx-core
        apt autoremove -y
        rm -rf /etc/nginx
        echo "==> Nginx 已完全卸载。"
    else
        echo "已取消卸载。"
    fi
    read -p "按回车键继续..."
}

# 循环显示菜单
while true; do
    show_menu
    case "$choice" in
        1) install_nginx ;;
        2) update_domain ;;
        3) add_domain ;;
        4) remove_domain ;;
        5) uninstall_nginx ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新选择！"; sleep 1 ;;
    esac
done

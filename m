#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (sudo bash menu.sh)"
  exit 1
fi

CONF_FILE="/etc/nginx/conf.d/b.conf"
CONFIG_RECORD="/etc/nginx/hgg_shortcut_name.conf" # 用于记录用户设置的快捷键名称

# 获取当前已设置的快捷键名称
get_current_shortcut() {
    if [ -f "$CONFIG_RECORD" ]; then
        cat "$CONFIG_RECORD"
    else
        echo "未设置 (请在选项 9 中设置)"
    fi
}

show_menu() {
    clear
    local current_cmd=$(get_current_shortcut)
    echo "======================================================"
    echo "       Nginx 域名、后端路径与反向代理管理菜单         "
    echo "======================================================"
    echo " 1. 安装 Nginx 并初始化反向代理配置"
    echo " 2. 修改 / 更改绑定的域名"
    echo " 3. 添加新域名"
    echo " 4. 删除指定的域名"
    echo " 5. 添加 / 修改指定的后端网址与端口路径 (Location)"
    echo " 6. 删除指定的后端端口路径"
    echo " 7. 查看当前的 Nginx 完整配置"
    echo " 8. 完全卸载 Nginx 及相关残留"
    echo " 9. 设置 / 更改全局快捷调用命令"
    echo " 0. 退出脚本"
    echo "------------------------------------------------------"
    echo " 💡 快捷键提示: 当前已绑定的快捷命令为 【 $current_cmd 】"
    echo "    在终端任意位置直接输入该命令即可随时调出此菜单！"
    echo "======================================================"
    read -p "请输入选项 [0-9]: " choice
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
    read -p "请输入新的主域名（多个域名用空格隔开）: " new_domains
    [ -z "$new_domains" ] && { echo "域名不能为空！"; read -p "按回车键继续..."; return; }
    
    if [ -f "$CONF_FILE" ]; then
        sed -i "s/server_name .*/server_name $new_domains;/" "$CONF_FILE"
        nginx -t && systemctl reload nginx
        echo "==> 域名已成功修改为: $new_domains"
    else
        echo "未找到配置文件！"
    fi
    read -p "按回车键继续..."
}

add_domain() {
    read -p "请输入要追加的新域名: " add_dom
    [ -z "$add_dom" ] && { echo "域名不能为空！"; read -p "按回车键继续..."; return; }
    
    if [ -f "$CONF_FILE" ]; then
        sed -i "/server_name/s/;/ $add_dom;/" "$CONF_FILE"
        nginx -t && systemctl reload nginx
        echo "==> 域名 $add_dom 添加成功！"
    else
        echo "未找到配置文件！"
    fi
    read -p "按回车键继续..."
}

remove_domain() {
    read -p "请输入想要移除的域名: " rm_dom
    if [ -f "$CONF_FILE" ]; then
        sed -i "s/$rm_dom//g" "$CONF_FILE"
        nginx -t && systemctl reload nginx
        echo "==> 域名 $rm_dom 已尝试移除。"
    else
        echo "未找到配置文件！"
    fi
    read -p "按回车键继续..."
}

manage_location() {
    echo "--------------------------------------------------"
    echo "提示：您可以添加多个路径（例如 /admin、 /api、 /panel 等）"
    echo "--------------------------------------------------"
    read -p "请输入要代理的访问路径（例如 /admin 或 /api）: " loc_path
    read -p "请输入完整的后端目标地址（例如 https://18.190.153.157:2096/admin）: " backend_url
    
    [ -z "$loc_path" ] || [ -z "$backend_url" ] && { echo "路径和后端地址均不能为空！"; read -p "按回车键继续..."; return; }

    [[ "$loc_path" != /* ]] && loc_path="/$loc_path"

    if [ -f "$CONF_FILE" ]; then
        new_loc_block="    location $loc_path {\n        proxy_pass $backend_url;\n        proxy_ssl_server_name on;\n        proxy_ssl_verify off;\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto \$scheme;\n        proxy_set_header X-Forwarded-Port \$server_port;\n        proxy_redirect off;\n        proxy_cookie_path / /;\n        proxy_buffer_size 128k;\n        proxy_buffers 4 256k;\n        proxy_busy_buffers_size 256k;\n    }\n}"

        sed -i '$d' "$CONF_FILE"
        echo -e "$new_loc_block" >> "$CONF_FILE"

        if nginx -t; then
            systemctl reload nginx
            echo "==> 路径 [ $loc_path ] 成功绑定并代理至 -> $backend_url"
        else
            echo "==> 配置有误，请检查！"
        fi
    else
        echo "未找到配置文件，请先安装！"
    fi
    read -p "按回车键继续..."
}

remove_location() {
    read -p "请输入想要删除的访问路径（例如 /admin）: " rm_loc
    [ -z "$rm_loc" ] && { echo "路径不能为空！"; read -p "按回车键继续..."; return; }
    echo "==> 如需精准删除复杂的 location，建议通过选项 7 查看配置后手动调整。"
    read -p "按回车键继续..."
}

view_config() {
    clear
    echo "==================== 当前 Nginx 配置 ===================="
    if [ -f "$CONF_FILE" ]; then
        cat "$CONF_FILE"
    else
        echo "配置文件不存在。"
    fi
    echo "========================================================="
    read -p "按回车键继续..."
}

set_shortcut() {
    echo "=========================================="
    read -p "请输入您想设置的快捷调用命令（例如输入 hgg）: " user_cmd
    if [ -n "$user_cmd" ]; then
        # 如果之前设置过其他快捷方式，先清理掉旧的软链接
        if [ -f "$CONFIG_RECORD" ]; then
            old_cmd=$(cat "$CONFIG_RECORD")
            rm -f "/usr/local/bin/$old_cmd"
        fi
        
        # 创建新的软链接
        target_bin="/usr/local/bin/$user_cmd"
        cp "$0" "$target_bin"
        chmod +x "$target_bin"
        
        # 记录到配置文件
        echo "$user_cmd" > "$CONFIG_RECORD"
        
        echo "==> 快捷命令 【 $user_cmd 】 设置成功！"
        echo "==> 以后在终端任意地方直接输入: $user_cmd 即可调出菜单。"
    else
        echo "输入为空，未作修改。"
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
        if [ -f "$CONFIG_RECORD" ]; then
            old_cmd=$(cat "$CONFIG_RECORD")
            rm -f "/usr/local/bin/$old_cmd"
            rm -f "$CONFIG_RECORD"
        fi
        echo "==> Nginx 及相关快捷方式已完全卸载。"
    else
        echo "已取消卸载。"
    fi
    read -p "按回车键继续..."
}

while true; do
    show_menu
    case "$choice" in
        1) install_nginx ;;
        2) update_domain ;;
        3) add_domain ;;
        4) remove_domain ;;
        5) manage_location ;;
        6) remove_location ;;
        7) view_config ;;
        8) uninstall_nginx ;;
        9) set_shortcut ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新选择！"; sleep 1 ;;
    esac
done

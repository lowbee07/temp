#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统, 请使用主流的操作系统" && exit 1

# 检测 VPS 处理器架构
archAffix() {
    case "$(uname -m)" in
        x86_64 | amd64) echo 'amd64' ;;
        armv8 | arm64 | aarch64) echo 'arm64' ;;
        s390x) echo 's390x' ;;
        *) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

install_base(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo tar openssl qrencode
}

install_singbox(){
    
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        green "Sing-box 已存在"
        exit 1
    fi

    install_base

    last_version=$(curl -s https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | sed -n 4p | tr -d ',"' | awk '{print $1}')
    if [[ -z $last_version ]]; then
        red "获取版本信息失败，请检查VPS的网络状态！"
        exit 1
    fi

    if [[ $SYSTEM == "CentOS" ]]; then
        wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$(archAffix).rpm -O sing-box.rpm
        rpm -ivh sing-box.rpm
        rm -f sing-box.rpm
    else
        wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$(archAffix).deb -O sing-box.deb
        dpkg -i sing-box.deb
        rm -f sing-box.deb
    fi

    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        green "Sing-box 安装成功！"
    else
        red "Sing-box 安装失败！"
        exit 1
    fi
}

makeConfig()
{
    stop_singbox

    port=$(shuf -i 20000-60000 -n 1)
    UUID=$(sing-box generate uuid)
    read -rp "请输入 Reality 目标域名 [默认世嘉官网]: " dest_server
    [[ -z $dest_server ]] && dest_server="www.sega.com"

    # Reality short-id
    short_id=$(openssl rand -hex 8)

    # Reality 公私钥
    keys=$(sing-box generate reality-keypair)
    private_key=$(echo $keys | awk -F " " '{print $2}')
    public_key=$(echo $keys | awk -F " " '{print $4}')

    # tuic v5
    port2=$(shuf -i 20000-60000 -n 1)
    tuic_pwd==$(openssl rand -hex 8)

    # 自签证书 www.bing.com www.tesla.com
    sni='www.bing.com'
    openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/private.key
    openssl req -new -x509 -days 36500 -key /etc/sing-box/private.key -out /etc/sing-box/cert.crt -subj "/CN=${sni}"
    chmod 777 /etc/sing-box/private.key
    chmod 777 /etc/sing-box/cert.crt

    # 将默认的配置文件删除，并写入
    rm -f /etc/sing-box/config.json
    cat << EOF > /etc/sing-box/config.json
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": $port,
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "uuid": "$UUID",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$dest_server",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "$dest_server",
                        "server_port": 443
                    },
                    "private_key": "$private_key",
                    "short_id": [
                        "$short_id"
                    ]
                }
            }
        },
        {
            "type": "tuic",
            "tag": "tuic-in",
            "listen": "::",
            "listen_port": $port2,
            "users": [
                {
                    "uuid": "$UUID",
                    "password": "$tuic_pwd"
                }
            ],
            "congestion_control": "bbr",
            "tls": {
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "/etc/sing-box/cert.crt",
                "key_path": "/etc/sing-box/private.key"
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ]
}
EOF

    IP=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*') || IP=$(expr "$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*')
    country=$(curl -s https://api.country.is  | awk -F '"' '{print $8}')

    mkdir /root/sing-box >/dev/null 2>&1

    # 生成 vless 分享链接及 Clash Meta 配置文件
    vless_link="vless://$UUID@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#${country}-vless-Reality"
    echo ${vless_link} > /root/sing-box/vless-link.txt
    
    tuic_link="tuic://${UUID}:${tuic_pwd}@${IP}:${port2}?sni=$sni&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${country}-tuic-v5"
    echo $tuic_link > /root/sing-box/tuic-link.txt

    start_singbox
}

showShareLink(){
    echo ""
    echo ""
    echo "Here is the link for v2rayN and v2rayNG :"
    echo ""
    yellow $(cat /root/sing-box/vless-link.txt)
    echo ""
    cat /root/sing-box/vless-link.txt | qrencode -s 120 -t ANSIUTF8 
    echo ""
    yellow $(cat /root/sing-box/tuic-link.txt) 
    echo ""
    cat /root/sing-box/tuic-link.txt | qrencode -s 120 -t ANSIUTF8 
    echo ""
}

uninstall_singbox(){
    systemctl stop sing-box >/dev/null 2>&1
    systemctl disable sing-box >/dev/null 2>&1
    ${PACKAGE_UNINSTALL} sing-box
    rm -rf /root/sing-box
    green "Sing-box 已彻底卸载成功！"
}

start_singbox(){
    systemctl start sing-box
    systemctl enable sing-box >/dev/null 2>&1
    
    if [[ -n $(systemctl status sing-box 2>/dev/null | grep -w active) && -f '/etc/sing-box/config.json' ]]; then
        green "Sing-box 服务启动成功"
    else
        red "Sing-box 服务启动失败，请运行 systemctl status sing-box 查看服务状态并反馈，脚本退出" && exit 1
    fi
}

stop_singbox(){
    systemctl stop sing-box
    systemctl disable sing-box >/dev/null 2>&1
}

menu(){
    clear
    echo "#############################################################"
    echo -e "#               ${RED}Sing-box Reality 一键安装脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    # echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    # echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    # echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Misaka-blog               #"
    # echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakanocchannel              #"
    # echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoc                     #"
    # echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Sing-box"
    echo -e " ${GREEN}2.${PLAIN} 卸载 Sing-box"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 启动 Sing-box"
    echo -e " ${GREEN}4.${PLAIN} 停止 Sing-box"
    echo -e " ${GREEN}5.${PLAIN} 重载 Sing-box"
    # echo " -------------"
    # echo -e " ${GREEN}6.${PLAIN} 全新的配置"
    echo " -------------"
    echo -e " ${GREEN}7.${PLAIN} show share link"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp " 请输入选项 [0-6] ：" answer
    case $answer in
        1) 
            install_singbox 
            makeConfig
            showShareLink
            ;;
        2) uninstall_singbox ;;
        3) start_singbox ;;
        4) stop_singbox ;;
        5) stop_singbox && start_singbox ;;
        # 6) makeConfig ;;
        7) showShareLink ;;
        *) red "请输入正确的选项 [0-6]！" && exit 1 ;;
    esac
}

menu
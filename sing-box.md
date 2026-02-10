### [sing-box](https://github.com/SagerNet/sing-box/)

```bash
sudo apt-get update
sudo apt-get install -y jq openssl qrencode

# last_version=$(curl -s https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | sed -n 4p | tr -d ',"' | awk '{print $1}')
last_version="1.12.16"
archAffix=amd64
wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$archAffix.deb -O sing-box.deb

sudo dpkg -i sing-box.deb
# remove 
# apt -y autoremove sing-box
systemctl status sing-box
```

```bash

IP=$(curl -s ipv4.wtfismyip.com/text)
country=$(curl -s https://api.country.is  | awk -F '"' '{print $8}')
uuid=$(sing-box generate uuid)

# vless-vision-reality
port=$(shuf -i 20000-60000 -n 1)
short_id=$(openssl rand -hex 8)
keys=$(sing-box generate reality-keypair)
private_key=$(echo $keys | awk -F " " '{print $2}')
public_key=$(echo $keys | awk -F " " '{print $4}')

dest_server="www.sega.com" # www.sega.com www.lovelive-anime.jp

# tuic v5
port2=$(shuf -i 20000-60000 -n 1)
tuic_pwd=$(openssl rand -hex 8)
# 自签证书 www.bing.com www.tesla.com
sni='www.bing.com'
openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/private.key
openssl req -new -x509 -days 36500 -key /etc/sing-box/private.key -out /etc/sing-box/cert.crt -subj "/CN=${sni}"
chmod 777 /etc/sing-box/private.key
chmod 777 /etc/sing-box/cert.crt

# 生成 vless 分享链接
vless_link="vless://$uuid@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp#${country}-vless-Reality"
echo ${vless_link} > vless-vision-reality.txt

tuic_link="tuic://${uuid}:${tuic_pwd}@${IP}:${port2}?sni=$sni&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${country}-tuic-v5"
echo $tuic_link > tuic-v5.txt
echo ""

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
            "users": [
                {
                    "uuid": "$uuid",
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
                    "uuid": "$uuid",
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

```

Shadowsocks

```SH
port3=$(shuf -i 20000-60000 -n 1) 
ss_link="ss://$(echo -n chacha20-ietf-poly1305:${uuid} | base64 -w 0)@${IP}:${port3}#${country}-ss"
echo ''
echo ${ss_link}
echo ''
echo ${ss_link} > shadowsocks.txt

cat << EOF
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": $port3,
            "method": "chacha20-ietf-poly1305",
            "password": "$uuid"
        }
EOF
```

```bash
echo "Here is the link for v2rayN and v2rayNG :"
echo ""
cat vless-vision-reality.txt
echo ""
cat vless-vision-reality.txt | qrencode -t ANSIUTF8 
echo ""
cat tuic-v5.txt
echo ""
cat tuic-v5.txt | qrencode -t ANSIUTF8 
echo ""
```

```bash
systemctl enable sing-box
systemctl restart sing-box

systemctl status sing-box

systemctl start sing-box
systemctl stop sing-box
systemctl disable sing-box

# 实时日志
journalctl -u sing-box -o cat -f
```
### reference
- [chika0801/sing-box-examples](https://github.com/chika0801/sing-box-examples/)
- [deathline94/sing-REALITY-Box](https://github.com/deathline94/sing-REALITY-Box)

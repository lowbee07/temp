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

# reality target site: www.lovelive-anime.jp www.sega.com
dest_server="www.sega.com" 
hostname=US

# 自签证书 www.bing.com d1.awsstatic.com
sni='www.bing.com'
openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/private.key
openssl req -new -x509 -days 200 -key /etc/sing-box/private.key -out /etc/sing-box/cert.crt -subj "/CN=${sni}"

IP=$(curl -s ipv4.wtfismyip.com/text)
# hostname=$(curl -s https://api.country.is  | awk -F '"' '{print $8}')

uuid=$(sing-box generate uuid)

# vless-vision-reality
# port=$(shuf -i 20000-60000 -n 1)
port=443
short_id=$(openssl rand -hex 8)
keys=$(sing-box generate reality-keypair)
private_key=$(echo $keys | awk -F " " '{print $2}')
public_key=$(echo $keys | awk -F " " '{print $4}')

# 生成 vless + reality 分享链接
vless_link="vless://$uuid@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp#${hostname}-VLESS-Reality"
echo ${vless_link} > vless-reality.txt

# vless + tls
# vless://$uuid@$IP:$port?type=tcp&encryption=none&flow=xtls-rprx-vision&security=tls&sni=${sni}&allowInsecure=1&fp=chrome#${hostname}-VLESS

# tuic v5
tuic_port=$(shuf -i 20000-60000 -n 1)
tuic_pwd=$(openssl rand -hex 8)

tuic_link="tuic://${uuid}:${tuic_pwd}@${IP}:${tuic_port}?sni=$sni&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${hostname}-TUIC"
echo $tuic_link > tuic.txt

# anytls
anytls_port=$(shuf -i 20000-60000 -n 1)
anytls_link="anytls://$uuid@${IP}:$anytls_port?&sni=$sni&insecure=1&fp=chrome#${hostname}-AnyTLS"
echo $anytls_link > anytls.txt

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
            "listen_port": $tuic_port,
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
        },
        {
            "type": "anytls",
            "tag": "anytls-in",
            "listen": "::",
            "listen_port": ${anytls_port},
            "users": [
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme": [],
            "tls":{
                "enabled": true,
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
ss_port=$(shuf -i 20000-60000 -n 1) 
ss_link="ss://$(echo -n chacha20-ietf-poly1305:${uuid} | base64 -w 0)@${IP}:${ss_port}#${hostname}-ss"
echo ''
echo ${ss_link}
echo ''
echo ${ss_link} > shadowsocks.txt

cat << EOF
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": $ss_port,
            "method": "chacha20-ietf-poly1305",
            "password": "$uuid"
        }
EOF
```

```bash
# echo "Here is the link for v2rayN and v2rayNG :"
echo ""
cat vless-reality.txt
echo ""
cat vless-reality.txt | qrencode -t ANSIUTF8 
echo ""
cat tuic.txt
echo ""
cat tuic.txt | qrencode -t ANSIUTF8 
echo ""
cat anytls.txt
echo ""
cat anytls.txt | qrencode -t ANSIUTF8 
echo ""
```

```bash
systemctl enable sing-box
systemctl restart sing-box

systemctl status sing-box

# systemctl start sing-box
# systemctl stop sing-box
# systemctl disable sing-box

# 实时日志
journalctl -u sing-box -o cat -f
```

replace reality target site

```bash

# reality target site: www.lovelive-anime.jp www.sega.com
old_server="www.sega.com" 
dest_server="www.lovelive-anime.jp"

sed -i "s_${old_server}_${dest_server}_" vless.txt
sed -i "s_${old_server}_${dest_server}_" /etc/sing-box/config.json

systemctl restart sing-box
``` 

### reference
- [chika0801/sing-box-examples](https://github.com/chika0801/sing-box-examples/)
- [deathline94/sing-REALITY-Box](https://github.com/deathline94/sing-REALITY-Box)

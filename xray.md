
## [xray](https://github.com/XTLS/Xray-core)
```bash
# Update package index and install dependencies
sudo apt-get update
sudo apt-get install -y jq openssl qrencode

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version 1.8.4
```
#### 

```sh
#!/bin/bash

# reality target site: www.lovelive-anime.jp www.sega.com
dest_server=www.lovelive-anime.jp
port=443
# port=$(shuf -i 20000-60000 -n 1) 
uuid=892dabdf-83e6-4783-862c-228f4d3a3dd9
private_key=EATh8IAcm_8BlmouL7cBc8S7S0SEKwDZ-iczwyLdEF0
public_key=UhDDXKj_mmkQB3t_h67dCdUcoPntqWAkYad9ILVcrUw
short_id=49701b29dd1a6926
serverIp=1.2.3.4
country=US

uuid=$(xray uuid)
keys=$(xray x25519)
private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')
short_id=$(openssl rand -hex 8)
# ws_path='/'$(echo $uuid | cut -d '-' -f 1)
serverIp=$(curl -s ipv4.wtfismyip.com/text)
country=$(curl -s https://api.country.is  | awk -F '"' '{print $8}')

# VLESS-Vision-REALITY
cat > /usr/local/etc/xray/config.json << EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "$dest_server:443",
                    "serverNames": [
                        "$dest_server"
                    ],
                    "privateKey": "$private_key",
                    "shortIds": [
                        "$short_id"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF

# Define colors as variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color/Reset

vless_link="vless://$uuid@$serverIp:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#$country-vless-vision-reality"
echo ${vless_link} > vless-vision-reality.txt
echo ''
echo -e "${YELLOW}${vless_link}${NC}"
echo ''
cat vless-vision-reality.txt | qrencode -t ANSIUTF8 
# qrencode -t ANSIUTF8 "$vless_link"
# qrencode -o qr.png "$vless_link"

#----------------------------------
systemctl enable xray
systemctl restart xray

systemctl status xray

# systemctl start xray
# systemctl stop xray
# systemctl disable xray

# 实时日志
# journalctl -u xray -o cat -f
```

Shadowsocks

```SH
port2=$(shuf -i 20000-60000 -n 1) 
ss_link="ss://$(echo -n chacha20-ietf-poly1305:${uuid} | base64 -w 0)@${serverIp}:${port2}#${country}-ss"
echo ''
echo ${ss_link}
echo ''
echo ${ss_link} > shadowsocks.txt

cat << EOF
        {
            "listen": "0.0.0.0",
            "port": $port2,
            "protocol": "shadowsocks",
            "settings": {
                "method": "chacha20-ietf-poly1305",
                "password": "$uuid"
            }
        }  
EOF
```

routing

```json
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:private", "geoip:cn"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "block"
            }
        ]
    }
```

#### [RealiTLScanner](https://github.com/XTLS/RealiTLScanner)
```sh
# run on your PC
./RealiTLScanner -addr 1.2.3.4
```

## reference
- [XTLS/Xray-examples](https://github.com/XTLS/Xray-examples)
- [chika0801/Xray-examples](https://github.com/chika0801/Xray-examples/)

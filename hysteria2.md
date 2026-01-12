
## [hysteria2](https://v2.hysteria.network/)
### install
```sh
# https://v2.hysteria.network/zh/docs/getting-started/Server-Installation-Script/
bash <(curl -fsSL https://get.hy2.sh/)

# 自签证书 www.bing.com www.tesla.com
sni='www.bing.com'
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=${sni}"
chmod 777 /etc/hysteria/cert.crt
chmod 777 /etc/hysteria/private.key

hy2_link="hysteria2://${uuid}@${serverIp}:${port2}?sni=${sni}&insecure=1#${country}-hy2"
echo ""
echo ${hy2_link}
# echo ${hy2_link} > hy2.txt


cat > /etc/hysteria/config.yaml << EOF
listen: :$port2

tls:
  cert: /etc/hysteria/cert.crt
  key: /etc/hysteria/private.key

auth:
  type: password
  password: ${uuid}

masquerade:
  type: proxy
  proxy:
    url: https://${sni}
    rewriteHost: true

EOF

# 启动Hysteria2
systemctl restart hysteria-server.service$

# 设置开机自启
systemctl enable hysteria-server.service$

```

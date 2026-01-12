### caddy

[Run-Caddy-as-a-daemon](https://github.com/klzgrad/naiveproxy/wiki/Run-Caddy-as-a-daemon)

```bash
# download
curl -sL -o caddy.tar.xz https://github.com/klzgrad/forwardproxy/releases/latest/download/caddy-forwardproxy-naive.tar.xz
tar -xJf caddy.tar.xz
chmod +x caddy-forwardproxy-naive/caddy
mv caddy-forwardproxy-naive/caddy /usr/bin/
# rm -rf caddy-forwardproxy-naive
# rm caddy.tar.xz

mkdir /etc/caddy
cat > /etc/caddy/Caddyfile << EOF
{
  order forward_proxy before file_server
}
:443, example.com {
  tls me@example.com
  forward_proxy {
    basic_auth user pass
    hide_ip
    hide_via
    probe_resistance
  }
  file_server {
    root /var/www/html
  }  
}
EOF

# 伪装网站
mkdir -p /var/www/html

```

Test if it works:
```sh
/usr/bin/caddy run --config /etc/caddy/Caddyfile
```

start the caddy service with systemd:
```sh
cat << EOF >/etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable caddy
systemctl start caddy

# Check the current status:
systemctl status caddy

# Reload caddy with changed config file:
systemctl reload caddy
```

#### Example Caddyfile
```
:443, naive.buliang0.tk #你的域名
tls example@example.com #你的邮箱
route {
 forward_proxy {
   basic_auth user pass #用户名和密码
   hide_ip
   hide_via
   probe_resistance
  }
 #支持多用户
 forward_proxy {
   basic_auth user2 pass2 #用户名和密码
   hide_ip
   hide_via
   probe_resistance
  }
 #伪装网址 
 reverse_proxy  https://www.tesla.com  { 
   header_up  Host  {upstream_hostport}
   header_up  X-Forwarded-Host  {host}
  }
}
```

### caddy

```bash
# download
cd /tmp
curl -sL -o caddy.tar.xz https://github.com/klzgrad/forwardproxy/releases/latest/download/caddy-forwardproxy-naive.tar.xz
tar -xJf caddy.tar.xz
mv caddy-forwardproxy-naive/caddy /usr/bin/
chmod +x /usr/bin/caddy

# 伪装网站
mkdir -p /var/www/html
wget https://github.com/HFIProgramming/mikutap/archive/refs/tags/2.0.0.tar.gz
tar -xzf mikutap-2.0.0.tar.gz
# rm -rf /var/www/html
# mv mikutap-2.0.0 /var/www/html

uuid=$(cat /proc/sys/kernel/random/uuid)
domain='你的域名'
email='你的邮箱'

mkdir /etc/caddy
cat > /etc/caddy/Caddyfile << EOF
{
  order forward_proxy before file_server
}
:443, $domain {   
  tls $email
  forward_proxy {
    basic_auth $uuid password
    hide_ip
    hide_via
    probe_resistance
  }
  file_server {
    root /var/www/html
  }  
}
EOF

```
Test if it works:
```sh
/usr/bin/caddy run --config /etc/caddy/Caddyfile
```

[Run Caddy as a daemon](https://github.com/klzgrad/naiveproxy/wiki/Run-Caddy-as-a-daemon)

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
 #伪装网址 
 reverse_proxy  https://www.tesla.com  { 
   header_up  Host  {upstream_hostport}
   header_up  X-Forwarded-Host  {host}
  }
}
```

# 01 502 Bad Gateway - Pythonアプリサービス停止

## 症状
curlでアクセスした時に502が表示される
## 期待される状態
pythonサーバのwebページが見えること
## 実際の状態
502 bad gateway
## 原因候補
nginx未起動
ポートが開いていない
proxyの設定ミス
pythonサービスの設定ミス
## 確認したログ・コマンド
Nginxの状態
systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running)
2. Pythonアプリサービスの状態
systemctl status myapp
● myapp.service - My Python App Service
     Loaded: loaded (/etc/systemd/system/myapp.service; disabled; preset: enabled)
     Active: inactive (dead)
3. ポート確認
ss -tulnp | grep -E '(:80|:3000)'
tcp   LISTEN 0      511        0.0.0.0:80       0.0.0.0:*    users:(("nginx",pid=1280,fd=6))
4. Pythonアプリ単体確認
curl http://127.0.0.1:3000
curl: (7) Failed to connect to 127.0.0.1 port 3000 after 0 ms: Connection refused
5. Nginx access.log
sudo tail -n 20 /var/log/nginx/access.log
127.0.0.1 - - [03/May/2026:10:15:22 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
6. Nginx error.log
sudo tail -n 20 /var/log/nginx/error.log
2026/05/03 10:15:22 [error] 1283#1283: *12 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
## 切り分け
Nginxは active だったため、Nginx停止の可能性は低い。
ssで80番がLISTENしていたため、Nginxは80番で待ち受けている。
access.logに /app/ へのアクセスと502が記録されていたため、リクエストはNginxまで届いている。
一方で、myapp.service は inactive だった。
また、ssで3000番のLISTENが確認できず、curl http://127.0.0.1:3000 も Connection refused となった。
そのため、Nginxのproxy_pass設定ミスよりも、upstreamであるPythonアプリサービスが停止している可能性が高いと判断した。
## 原因
pythonサービスが起動していなかった
systemctl status で動いていないし、ss でポートも開いていないし、error.logで通信が拒否されたとある
## 解決
pythonサービスを起動する
sudo systemctl start myapp
ss -tulnp | grep :3000
## 解決後の確認
もう一度curlでアクセスしてみる
curl http://localhost:3000
## 学び
502 Bad Gateway は、Nginx自体が停止しているという意味ではない。
Nginxが動いていても、裏側のupstreamであるPythonアプリサービスが停止していると502になる。
また、access.logではNginxまでリクエストが届いていること、error.logではNginxがupstreamに接続できなかったことを確認できる。
502の切り分けでは、Nginxだけでなく、裏側のサービス状態と待ち受けポートを確認する必要がある。

# 05 502 Bad Gateway - Pythonアプリのbind先ミス

## 概要

Nginx経由で `/app/` にアクセスしたところ、`502 Bad Gateway` が発生した。

調査の結果、Nginx自体は起動しており、Pythonアプリサービスも `active (running)` だった。

また、3000番ポートもLISTENしていたが、Pythonアプリは `127.0.0.1:3000` ではなく、`192.168.1.50:3000` で待ち受けていた。

一方で、Nginxの `proxy_pass` は `127.0.0.1:3000` を指定していたため、Nginxが接続しようとした先にPythonアプリが存在せず、502が発生していた。

---

## 症状

`curl` でNginx経由のURLへアクセスしたところ、`502 Bad Gateway` が表示された。

```bash
curl http://localhost/app/
```
## 期待される状態

Nginx経由でPythonアプリにアクセスし、PythonサーバのWebページが表示されること。

## 実際の状態

502 Bad Gateway が返ってきた。

## 原因候補

考えられる原因は以下。

- Pythonアプリサービスが起動していない
- Nginx設定ファイルの proxy_pass 設定が間違っている
- Pythonアプリが3000番でLISTENしていない
- Pythonアプリが別のIPやポートでLISTENしている
- myapp.service 設定ファイルが間違っている
- Pythonアプリの --bind 先とNginxの proxy_pass 先が一致していない
## 確認したログ・コマンド
### 1. Nginxの状態確認
```bash
systemctl status nginx
```
確認結果。
```txt
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running)
```
Nginxは active (running) のため、Nginxサービスは起動していた。

### 2. Pythonアプリサービスの状態確認
```bash
systemctl status myapp
```
確認結果。
```txt
● myapp.service - My Python App Service
     Loaded: loaded (/etc/systemd/system/myapp.service; disabled; preset: enabled)
     Active: active (running)
```
Pythonアプリサービスも active (running) のため、サービス自体は起動していた。

### 3. ポート確認
```bash
ss -tulnp | grep -E '(:80|:3000)'
```
確認結果。
```txt
tcp   LISTEN 0      511        0.0.0.0:80          0.0.0.0:*    users:(("nginx",pid=1280,fd=6))
tcp   LISTEN 0      5        192.168.1.50:3000     0.0.0.0:*    users:(("python3",pid=1880,fd=3))
```
80番はNginxがLISTENしていた。

3000番はPythonアプリがLISTENしていたが、待ち受けているIPアドレスは 127.0.0.1 ではなく、192.168.1.50 だった。

### 4. Pythonアプリ単体確認：127.0.0.1
```bash
curl http://127.0.0.1:3000
```
確認結果。
```txt
curl: (7) Failed to connect to 127.0.0.1 port 3000 after 0 ms: Connection refused
```
127.0.0.1:3000 には接続できなかった。

つまり、Pythonアプリは 127.0.0.1:3000 では待ち受けていなかった。

### 5. Pythonアプリ単体確認：192.168.1.50
```bash
curl http://192.168.1.50:3000
```
確認結果。
```txt
Hello from Python App Service
```
192.168.1.50:3000 ではPythonアプリに接続できた。

このことから、Pythonアプリは起動しており、192.168.1.50:3000 で待ち受けていると判断した。

### 6. Nginx経由の確認
```bash
curl http://localhost/app/
```
確認結果。
```txt
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.24.0</center>
</body>
</html>
```
Nginx経由でアクセスすると502になった。

Pythonアプリ自体は起動しているため、NginxからPythonアプリへの接続先に問題がある可能性が高いと判断した。

### 7. Nginx access.logの確認
```bash
sudo tail -n 20 /var/log/nginx/access.log
```
確認結果。
```txt
127.0.0.1 - - [03/May/2026:12:35:12 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
```
access.log に /app/ へのアクセスと502が記録されていた。

このことから、リクエストはNginxまで届いていると判断した。

### 8. Nginx error.logの確認
```bash
sudo tail -n 30 /var/log/nginx/error.log
```
確認結果。
```txt
2026/05/03 12:35:12 [error] 1283#1283: *31 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
```
Nginxはupstreamである http://127.0.0.1:3000/ に接続しようとしていた。

しかし、Pythonアプリは 127.0.0.1:3000 では待ち受けていないため、Connection refused になっていた。

### 9. myapp.serviceのExecStart確認
```bash
grep -n "ExecStart" /etc/systemd/system/myapp.service
```
確認結果。
```txt
8:ExecStart=/usr/bin/python3 -m http.server 3000 --bind 192.168.1.50
```
Pythonアプリは --bind 192.168.1.50 により、192.168.1.50:3000 で待ち受ける設定になっていた。

### 10. Nginx設定ファイルのproxy_pass確認
```bash
grep -n "proxy_pass" /etc/nginx/sites-enabled/default
```
確認結果。
```txt
48:        proxy_pass http://127.0.0.1:3000/;
```
Nginxは http://127.0.0.1:3000/ へリクエストを中継する設定になっていた。

しかし、Pythonアプリは 192.168.1.50:3000 で待ち受けているため、Nginxの接続先とPythonアプリの待ち受けIPが一致していなかった。

## 切り分け

Nginxは active (running) であり、80番ポートもLISTENしていた。

そのため、Nginxサービス停止や80番ポートの待ち受け不備ではないと判断した。

Pythonアプリサービスも active (running) であり、3000番ポートもLISTENしていた。

ただし、ss の結果を見ると、Pythonアプリは 127.0.0.1:3000 ではなく、192.168.1.50:3000 でLISTENしていた。

curl http://127.0.0.1:3000 は Connection refused となったが、curl http://192.168.1.50:3000 は成功した。

このことから、Pythonアプリ自体は起動しているが、127.0.0.1 では待ち受けていないと判断した。

Nginx経由で curl http://localhost/app/ を実行すると502になった。

access.log にも /app/ へのアクセスと502が記録されており、リクエストはNginxまで届いていた。

Nginxの error.log では、upstreamが http://127.0.0.1:3000/ になっていた。

また、Nginx設定ファイルの proxy_pass も http://127.0.0.1:3000/ になっていた。

一方で、myapp.service の ExecStart では --bind 192.168.1.50 が指定されていた。

つまり、Nginxは 127.0.0.1:3000 に接続しようとしているが、Pythonアプリは 192.168.1.50:3000 で待ち受けていた。

以上から、Pythonアプリの --bind 先とNginxの proxy_pass 先が一致していないことが原因だと判断した。

## 原因

Pythonアプリの待ち受けIPアドレスと、Nginxの proxy_pass 先が一致していなかった。

myapp.service では、Pythonアプリが 192.168.1.50:3000 で待ち受けるように設定されていた。
```bash
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 192.168.1.50
```
一方で、Nginxは 127.0.0.1:3000 へリクエストを中継する設定になっていた。
```bash
proxy_pass http://127.0.0.1:3000/;
```
そのため、Nginxが接続しようとした 127.0.0.1:3000 にはPythonアプリが存在せず、502 Bad Gateway が発生した。

## 解決

今回の構成では、Pythonアプリを外部に直接公開せず、Nginx経由でアクセスさせたい。

そのため、Nginxの proxy_pass はそのままにして、Pythonアプリを 127.0.0.1:3000 で待ち受けるように修正する。

myapp.service を編集する。
```bash
sudo nano /etc/systemd/system/myapp.service
```
修正前。
```bash
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 192.168.1.50
```
修正後。
``` bash
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 127.0.0.1
```
設定変更をsystemdに反映する。
```bash
sudo systemctl daemon-reload
```
myapp.service を再起動する。
```bash
sudo systemctl restart myapp
```
解決後の確認

Pythonアプリサービスの状態を確認する。
```bash
systemctl status myapp
```
3000番ポートの待ち受けを確認する。
```bash
ss -tulnp | grep ':3000'
```
Pythonアプリ単体の応答を確認する。
```bash
curl http://127.0.0.1:3000
```
Nginx経由の応答を確認する。
```bash
curl http://localhost/app/
```
どちらも index.html の内容が返れば復旧完了。

## 学び

- --bind は、PythonアプリがどのIPアドレスで待ち受けるかを指定する設定である。

- 一方で、WorkingDirectory は、Pythonアプリがどのディレクトリのファイルを配信するかを指定する設定である。

- ポート番号が同じでも、待ち受けているIPアドレスが異なると接続できない場合がある。

- 今回、Pythonアプリは 192.168.1.50:3000 で待ち受けていたが、Nginxは 127.0.0.1:3000 へ接続しようとしていた。

- そのため、3000番ポート自体はLISTENしていても、Nginxが接続する先にはPythonアプリが存在せず502になった。

- 502の切り分けでは、ポート番号だけでなく、待ち受けているIPアドレスまで確認することが重要だと分かった。
```bash
127.0.0.1:3000
192.168.1.50:3000
```
この2つは同じ3000番ポートでも、待ち受けているIPアドレスが違うため、接続先としては別物として考える必要がある。

# 06 502 Bad Gateway - Nginxの不要なヘッダー設定

## 概要

Nginx経由で `/app/` にアクセスしたところ、`502 Bad Gateway` が発生した。

調査の結果、NginxもPythonアプリサービスも起動しており、80番ポートと3000番ポートも正常にLISTENしていた。

また、Pythonアプリ単体には正常にアクセスできた。

しかし、Nginx経由でアクセスした場合のみ502が発生しており、Nginxの `error.log` には `upstream prematurely closed connection while reading response header from upstream` が記録されていた。

Nginx設定を確認すると、Pythonの簡易HTTPサーバには不要な `proxy_http_version 1.1` と `proxy_set_header Connection "upgrade";` が設定されていた。

この設定を削除したところ復旧したため、Nginxからupstreamへ送るヘッダー設定が原因だったと判断した。

---

## 症状

`curl` でNginx経由のURLへアクセスしたところ、`502 Bad Gateway` が表示された。

```bash
curl http://localhost/app/
```

---

## 期待される状態

Nginx経由でPythonアプリにアクセスし、PythonサーバのWebページが表示されること。

---

## 実際の状態

Nginx経由でアクセスすると、`502 Bad Gateway` が返った。

---

## 原因候補

考えられる原因は以下。

- Nginxサービスが停止している
- Pythonアプリサービスが停止している
- Pythonアプリが3000番ポートでLISTENしていない
- Nginxの `proxy_pass` 先が間違っている
- Nginxの `proxy_set_header` や `proxy_http_version` など、中継設定に問題がある

---

## 確認したログ・コマンド

### 1. Nginxの状態確認

```bash
systemctl status nginx
```

確認結果。

```text
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-05-03 13:10:02 JST; 12min ago
```

Nginxは `active (running)` のため、Nginxサービス自体は起動していた。

---

### 2. Pythonアプリサービスの状態確認

```bash
systemctl status myapp
```

確認結果。

```text
● myapp.service - My Python App Service
     Loaded: loaded (/etc/systemd/system/myapp.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-05-03 13:09:48 JST; 12min ago
   Main PID: 2118 (python3)
   CGroup: /system.slice/myapp.service
           └─2118 /usr/bin/python3 -m http.server 3000 --bind 127.0.0.1
```

Pythonアプリサービスも `active (running)` のため、サービス自体は起動していた。

---

### 3. ポート確認

```bash
ss -tulnp | grep -E '(:80|:3000)'
```

確認結果。

```text
tcp   LISTEN 0      511        0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=2140,fd=6))
tcp   LISTEN 0      5        127.0.0.1:3000      0.0.0.0:*    users:(("python3",pid=2118,fd=3))
```

80番はNginx、3000番はPythonアプリがLISTENしていた。

Pythonアプリは、Nginxの `proxy_pass` 先と同じ `127.0.0.1:3000` で待ち受けていた。

---

### 4. Pythonアプリ単体の確認

```bash
curl http://localhost:3000
```

確認結果。

```text
Hello from Python App Service
```

Pythonアプリ単体には正常にアクセスできた。

そのため、Pythonアプリの起動状態や3000番ポートの待ち受けは問題ないと判断した。

---

### 5. Nginx access.logの確認

```bash
sudo tail -n 5 /var/log/nginx/access.log
```

確認結果。

```text
127.0.0.1 - - [03/May/2026:13:21:40 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
127.0.0.1 - - [03/May/2026:13:21:58 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
127.0.0.1 - - [03/May/2026:13:22:13 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
```

`/app/` へのアクセスはNginxまで届いていた。

ただし、Nginxは502を返していた。

---

### 6. Nginx error.logの確認

```bash
sudo tail -n 5 /var/log/nginx/error.log
```

確認結果。

```text
2026/05/03 13:21:40 [error] 2141#2141: *41 upstream prematurely closed connection while reading response header from upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
2026/05/03 13:21:58 [error] 2141#2141: *43 upstream prematurely closed connection while reading response header from upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
2026/05/03 13:22:13 [error] 2141#2141: *45 upstream prematurely closed connection while reading response header from upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
```

`Connection refused` ではなく、`upstream prematurely closed connection while reading response header from upstream` が記録されていた。

これは、Nginxがupstreamへ接続したものの、レスポンスヘッダーを受け取る前にupstream側が接続を閉じたことを示している。

このため、upstream自体が存在しないというより、Nginxからupstreamへ送るリクエスト内容や中継設定に問題がある可能性を考えた。

---

### 7. Nginx設定ファイルの確認

```bash
sudo cat /etc/nginx/sites-enabled/default
```

確認結果。

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location /app/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_http_version 1.1;
        proxy_set_header Connection "upgrade";
    }
}
```

`proxy_pass` は `http://127.0.0.1:3000/` を向いており、Pythonアプリの待ち受け先と一致していた。

一方で、以下の設定が含まれていた。

```nginx
proxy_http_version 1.1;
proxy_set_header Connection "upgrade";
```

`proxy_set_header Connection "upgrade";` は、Nginxがupstreamへ送るHTTPヘッダーを変更する設定である。

今回のPython簡易HTTPサーバには不要な設定だったため、この部分が原因の可能性があると考えた。

---

### 8. myapp.serviceの確認

```bash
sudo cat /etc/systemd/system/myapp.service
```

確認結果。

```ini
[Unit]
Description=My Python App Service
After=network.target

[Service]
User=toki
WorkingDirectory=/home/toki/myapp
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

`myapp.service` の `ExecStart`、`WorkingDirectory`、bind先は想定通りだった。

Pythonアプリサービス側の設定には大きな問題がなさそうだと判断した。

---

## 切り分け

Nginxは `active (running)` であり、80番ポートもLISTENしていた。

Pythonアプリサービスも `active (running)` であり、3000番ポートも `127.0.0.1:3000` でLISTENしていた。

また、`curl http://localhost:3000` ではPythonアプリ単体に正常にアクセスできた。

このため、Pythonアプリの起動状態、待ち受けポート、bind先は問題ないと判断した。

一方で、`curl http://localhost/app/` では `502 Bad Gateway` が返った。

`access.log` には `/app/` へのアクセスと502が記録されており、リクエストはNginxまで届いていた。

`error.log` には `upstream prematurely closed connection while reading response header from upstream` と出ていた。

これは、NginxがupstreamであるPythonアプリからレスポンスヘッダーを受け取る前に、upstream側が接続を閉じたことを示している。

Nginx設定ファイルを確認すると、`proxy_pass` は `http://127.0.0.1:3000/` で正しく、Pythonアプリの待ち受け先と一致していた。

しかし、`proxy_http_version 1.1` と `proxy_set_header Connection "upgrade";` が設定されていた。

`proxy_set_header Connection "upgrade";` はURLを書き換える設定ではなく、Nginxがupstreamへ送るHTTPヘッダーを変更する設定である。

今回のPython簡易HTTPサーバには不要なヘッダー設定だったため、Nginxからupstreamへ送るリクエスト内容が通常と異なり、Pythonアプリが正常に応答できなかった可能性が高いと判断した。

---

## 原因

Nginxの `location /app/` に、Pythonの簡易HTTPサーバには不要なヘッダー設定が含まれていた。

```nginx
proxy_http_version 1.1;
proxy_set_header Connection "upgrade";
```

この設定により、NginxがupstreamであるPythonアプリへ `Connection: upgrade` ヘッダーを送っていた。

Pythonアプリ単体では正常に応答し、Nginxの `proxy_pass` 先も `127.0.0.1:3000` で一致していた。

しかし、Nginx経由ではupstreamがレスポンスヘッダーを返す前に接続を閉じたため、`502 Bad Gateway` が発生した。

削除後にNginx経由でも正常に応答したため、この不要なヘッダー設定が原因だったと判断した。

---

## 解決

Nginx設定ファイルから、Python簡易HTTPサーバには不要な以下の設定を削除する。

削除する設定。

```nginx
proxy_http_version 1.1;
proxy_set_header Connection "upgrade";
```

修正後。

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location /app/ {
        proxy_pass http://127.0.0.1:3000/;
    }
}
```

設定ファイルの構文を確認する。

```bash
sudo nginx -t
```

Nginxに設定を反映する。

```bash
sudo systemctl reload nginx
```

---

## 解決後の確認

Pythonアプリ単体の応答を確認する。

```bash
curl http://127.0.0.1:3000
```

Nginx経由の応答を確認する。

```bash
curl http://localhost/app/
```

どちらも `index.html` の内容が返れば復旧完了。

---

## 学び

`proxy_set_header` はURLを書き換える設定ではなく、Nginxがupstreamへ送るHTTPヘッダーを追加・変更する設定である。

今回の `Connection: upgrade` は、通常のHTTP通信から別の通信方式へ切り替える意図を持つヘッダーであり、WebSocketなどで使われることがある。

しかし、今回のPython簡易HTTPサーバには不要な設定だった。

`502 Bad Gateway` では、upstreamが停止している場合だけでなく、Nginxからupstreamへ送るHTTPリクエストの内容が不適切で、upstream側が正常に応答できない場合もある。

Pythonアプリ単体では成功するのに、Nginx経由だけ失敗する場合は、`proxy_pass` だけでなく、`proxy_set_header` や `proxy_http_version` などのNginx側の中継設定も確認する必要がある。

---

## Connection refusedとの違い

同じ502でも、`error.log` の内容によって疑う場所が変わる。

```text
connect() failed (111: Connection refused) while connecting to upstream
→ upstreamのプロセスがいない、または指定先IP・ポートで待ち受けていない可能性が高い

upstream prematurely closed connection while reading response header from upstream
→ upstreamには接続できたが、レスポンスを返す前に接続が閉じられた可能性がある
```

今回のケースでは、Pythonアプリは起動しており、3000番ポートでも待ち受けていた。

そのため、`Connection refused` ではなく、Nginxからupstreamへ送るリクエスト内容や中継設定を疑った。

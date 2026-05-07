# 02 502 Bad Gateway - proxy_passのポート不一致

## 概要

Nginx経由で `/app/` にアクセスしたところ、`502 Bad Gateway` が発生した。

調査の結果、Pythonアプリ自体は起動しており、3000番ポートで正常に待ち受けていた。

しかし、Nginxの `proxy_pass` が存在しない3999番ポートを指定していたため、Nginxがupstreamへ接続できず、502が発生していた。

---

## 症状

`curl` でNginx経由のURLへアクセスしたところ、`502 Bad Gateway` が表示された。

```bash
curl http://localhost/app/
```

---

## 期待される状態

PythonアプリのWebページが表示されること。

---

## 実際の状態

`502 Bad Gateway` が返ってきた。

```html
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.24.0</center>
</body>
</html>
```

---

## 原因候補

考えられる原因は以下。

- Nginxが起動していない
- Nginxは起動しているが、80番ポートで待ち受けていない
- Pythonアプリサービスが停止している
- Pythonアプリが3000番ポートで待ち受けていない
- Nginxの `proxy_pass` の設定が間違っている

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
     Active: active (running)
```

Nginxは `active (running)` だった。

---

### 2. Pythonアプリサービスの状態確認

```bash
systemctl status myapp
```

確認結果。

```text
● myapp.service - My Python App Service
     Loaded: loaded (/etc/systemd/system/myapp.service; disabled; preset: enabled)
     Active: active (running)
```

`myapp.service` も `active (running)` だった。

---

### 3. ポート確認

```bash
ss -tulnp | grep -E '(:80|:3000|:3999)'
```

確認結果。

```text
tcp   LISTEN 0      511        0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=1280,fd=6))
tcp   LISTEN 0      5        127.0.0.1:3000      0.0.0.0:*    users:(("python3",pid=1442,fd=3))
```

80番ポートと3000番ポートはLISTENしていた。

一方で、3999番ポートはLISTENしていなかった。

---

### 4. Pythonアプリ単体確認

```bash
curl http://127.0.0.1:3000
```

確認結果。

```text
Hello from Python App Service
```

Pythonアプリ単体には正常にアクセスできた。

---

### 5. Nginx経由の確認

```bash
curl http://localhost/app/
```

確認結果。

```html
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.24.0</center>
</body>
</html>
```

Pythonアプリ単体は正常だが、Nginx経由では502になった。

---

### 6. Nginx access.log

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

確認結果。

```text
127.0.0.1 - - [03/May/2026:11:02:10 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
```

`/app/` へのアクセスがNginxまで届き、502が返っていることを確認した。

---

### 7. Nginx error.log

```bash
sudo tail -n 30 /var/log/nginx/error.log
```

確認結果。

```text
2026/05/03 11:02:10 [error] 1283#1283: *18 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3999/", host: "localhost"
```

Nginxがupstreamである `127.0.0.1:3999` に接続しようとして、接続を拒否されたことが分かる。

---

### 8. Nginx設定ファイルの確認

```bash
sudo grep -n "proxy_pass" /etc/nginx/sites-enabled/default
```

確認結果。

```text
48:        proxy_pass http://127.0.0.1:3999/;
```

Nginxの `proxy_pass` が、Pythonアプリの待ち受けポートである3000番ではなく、3999番を指定していた。

---

## 切り分け

Nginxは `active (running)` だったため、Nginx停止の可能性は低い。

また、80番ポートがLISTENしていたため、NginxはHTTPリクエストを受け取れる状態だった。

`myapp.service` も `active (running)` であり、3000番ポートもLISTENしていた。

さらに、`curl http://127.0.0.1:3000` でPythonアプリ単体には正常にアクセスできた。

一方で、Nginx経由の `curl http://localhost/app/` では502が返った。

`access.log` には `/app/` へのアクセスと502が記録されており、リクエストはNginxまで届いていた。

`error.log` には、Nginxが `127.0.0.1:3999` へ接続しようとして `Connection refused` になったことが記録されていた。

さらに、Nginx設定ファイルを確認すると、`proxy_pass` が `127.0.0.1:3999` を指定していた。

しかし、実際にPythonアプリが待ち受けているのは3000番ポートだった。

このことから、原因はPythonアプリ停止ではなく、Nginxの `proxy_pass` のポート不一致だと判断した。

---

## 原因

Nginx設定ファイルの `proxy_pass` が、Pythonアプリが待ち受けていない3999番ポートを指定していた。

```nginx
proxy_pass http://127.0.0.1:3999/;
```

実際にPythonアプリが待ち受けていたのは3000番ポートだった。

```text
127.0.0.1:3000
```

そのため、Nginxがupstreamへ接続できず、`502 Bad Gateway` が発生した。

---

## 解決

Nginx設定ファイルの `proxy_pass` を、Pythonアプリが待ち受けている3000番ポートへ修正した。

修正前。

```nginx
proxy_pass http://127.0.0.1:3999/;
```

修正後。

```nginx
proxy_pass http://127.0.0.1:3000/;
```

---

## 解決後の確認

Nginx設定ファイルに構文エラーがないか確認する。

```bash
sudo nginx -t
```

設定を反映する。

```bash
sudo systemctl reload nginx
```

Nginx経由で再度アクセスする。

```bash
curl http://localhost/app/
```

PythonアプリのWebページが表示されれば解決。

---

## 学び

Pythonアプリ単体にアクセスできるのに、Nginx経由で失敗する場合は、Nginx側の設定やNginxからupstreamへの中継部分を優先して確認する必要がある。

今回のように、`myapp.service` が起動していて、3000番ポートもLISTENしており、Pythonアプリ単体にもアクセスできる場合、Pythonアプリ側の問題である可能性は低い。

一方で、Nginx経由でのみ502が出ている場合は、`proxy_pass` の指定先やupstreamへの接続状況を確認する必要がある。

`error.log` の `upstream: "http://127.0.0.1:3999/"` を見ることで、Nginxが実際にどのポートへ接続しようとしていたかを確認できた。

502の切り分けでは、以下を分けて確認することが重要だと分かった。

```text
1. Nginx自体は起動しているか
2. upstreamのサービスは起動しているか
3. upstreamのポートはLISTENしているか
4. Pythonアプリ単体にはアクセスできるか
5. Nginxのproxy_passは正しいポートを指定しているか
6. error.logのupstream先はどこになっているか
```

---

## Pythonアプリサービス停止との違い

同じ `502 Bad Gateway` でも、原因によって確認結果が変わる。

```text
Pythonアプリサービス停止
→ myapp.service が inactive
→ 3000番ポートがLISTENしていない
→ Pythonアプリ単体にも接続できない

proxy_passポート不一致
→ myapp.service は active
→ Pythonアプリは3000番でLISTENしている
→ Pythonアプリ単体には接続できる
→ しかしNginxが3999番ポートへ接続しようとしている
```

今回のケースでは、Pythonアプリ自体は正常に起動していたが、Nginxの `proxy_pass` が存在しない3999番ポートを指定していたため、Nginxからupstreamへ接続できなかった。


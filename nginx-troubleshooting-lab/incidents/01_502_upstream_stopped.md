# 01 502 Bad Gateway - Pythonアプリサービス停止

## 概要

Nginx経由で `/app/` にアクセスしたところ、`502 Bad Gateway` が発生した。

調査の結果、Nginx自体は起動していたが、upstreamである `myapp.service` が停止しており、Pythonアプリが3000番ポートで待ち受けていないことが原因だった。

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

---

## 原因候補

考えられる原因は以下。

- Nginxが起動していない
- Nginxは起動しているが、80番ポートで待ち受けていない
- `proxy_pass` の設定が間違っている
- Pythonアプリサービスが停止している
- Pythonアプリが3000番ポートで待ち受けていない

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
     Active: inactive (dead)
```

`myapp.service` は `inactive (dead)` だった。

---

### 3. ポート確認

```bash
ss -tulnp | grep -E '(:80|:3000)'
```

確認結果。

```text
tcp   LISTEN 0      511        0.0.0.0:80       0.0.0.0:*    users:(("nginx",pid=1280,fd=6))
```

80番ポートはLISTENしていたが、3000番ポートはLISTENしていなかった。

---

### 4. Pythonアプリ単体確認

```bash
curl http://127.0.0.1:3000
```

確認結果。

```text
curl: (7) Failed to connect to 127.0.0.1 port 3000 after 0 ms: Connection refused
```

Pythonアプリに直接アクセスしても接続できなかった。

---

### 5. Nginx access.log

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

確認結果。

```text
127.0.0.1 - - [03/May/2026:10:15:22 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
```

`/app/` へのアクセスがNginxまで届き、502が返っていることを確認した。

---

### 6. Nginx error.log

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

確認結果。

```text
2026/05/03 10:15:22 [error] 1283#1283: *12 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
```

Nginxがupstreamである `127.0.0.1:3000` に接続しようとしたが、接続を拒否されたことが分かる。

---

## 切り分け

Nginxは `active (running)` だったため、Nginx停止の可能性は低い。

また、`ss` で80番ポートがLISTENしていたため、NginxはHTTPリクエストを受け取れる状態だった。

`access.log` には `/app/` へのアクセスと502が記録されていたため、リクエストはNginxまで届いていた。

一方で、`myapp.service` は `inactive (dead)` だった。

さらに、`ss` で3000番ポートのLISTENが確認できず、`curl http://127.0.0.1:3000` でも `Connection refused` となった。

このことから、Nginxの設定ミスではなく、upstreamであるPythonアプリサービスが停止している可能性が高いと判断した。

---

## 原因

Pythonアプリサービスである `myapp.service` が停止していた。

そのため、Nginxが `proxy_pass` で指定された `127.0.0.1:3000` に接続できず、`502 Bad Gateway` が発生した。

---

## 解決

停止していた `myapp.service` を起動した。

```bash
sudo systemctl start myapp
```

3000番ポートで待ち受けているか確認した。

```bash
ss -tulnp | grep ':3000'
```

---

## 解決後の確認

Nginx経由で再度アクセスする。

```bash
curl http://localhost/app/
```

Pythonアプリ単体にもアクセスできることを確認する。

```bash
curl http://127.0.0.1:3000
```

どちらもPythonアプリの内容が返れば復旧完了。

---

## 学び

`502 Bad Gateway` は、Nginx自体が停止しているという意味ではない。

Nginxが起動していても、裏側のupstreamであるPythonアプリサービスが停止していると502になる。

今回の検証では、`access.log` からリクエストがNginxまで届いていることを確認できた。

また、`error.log` の `connect() failed (111: Connection refused) while connecting to upstream` から、Nginxがupstreamに接続できなかったことを確認できた。

502の切り分けでは、Nginxだけでなく、upstreamのサービス状態・待ち受けポート・直接アクセスの確認が重要だと分かった。

---

## proxy_passポート不一致との違い

同じ `502 Bad Gateway` でも、原因によって確認結果が変わる。

```text
Pythonアプリサービス停止
→ myapp.service が inactive
→ 3000番ポートがLISTENしていない
→ Pythonアプリ単体にも接続できない

proxy_passポート不一致
→ myapp.service は active
→ Pythonアプリは3000番でLISTENしている
→ しかしNginxが別のポートへ接続しようとしている
```

今回のケースでは、`myapp.service` 自体が停止していたため、3000番ポートで待ち受けるプロセスが存在せず、Nginxがupstreamへ接続できなかった。

# 04 502 Bad Gateway - systemd WorkingDirectoryミス

## 概要

Nginx経由で `/app/` にアクセスしたところ、`502 Bad Gateway` が発生した。

調査の結果、Nginx自体は起動しており、80番ポートで待ち受けていた。

しかし、`myapp.service` の `WorkingDirectory` に存在しないディレクトリを指定していたため、systemdがサービス起動時に作業ディレクトリへ移動できず、Pythonアプリの起動に失敗していた。

その結果、3000番ポートで待ち受けるプロセスが存在せず、Nginxがupstreamへ接続できなかったため、502が発生していた。

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

`502 Bad Gateway` が返ってきた。

---

## 原因候補

考えられる原因は以下。

- Nginxサービスが停止している
- Nginxが80番ポートで待ち受けていない
- Nginxの `proxy_pass` 設定が間違っている
- Pythonアプリサービスが停止、または起動に失敗している
- Pythonアプリが3000番ポートで待ち受けていない
- Pythonアプリが別のIPやポートで待ち受けている
- `myapp.service` の `WorkingDirectory` に誤りがある

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

Nginxは `active (running)` のため、Nginxサービスは起動していた。

---

### 2. Pythonアプリサービスの状態確認

```bash
systemctl status myapp
```

確認結果。

```text
● myapp.service - My Python App Service
     Loaded: loaded (/etc/systemd/system/myapp.service; disabled; preset: enabled)
     Active: failed (Result: exit-code) since Sun 2026-05-03 12:05:14 JST; 1min 30s ago
    Process: 1744 ExecStart=/usr/bin/python3 -m http.server 3000 --bind 127.0.0.1 (code=exited, status=200/CHDIR)
   Main PID: 1744 (code=exited, status=200/CHDIR)

May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Changing to the requested working directory failed: No such file or directory
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Failed at step CHDIR spawning /usr/bin/python3: No such file or directory
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Main process exited, code=exited, status=200/CHDIR
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Failed with result 'exit-code'.
```

`myapp.service` は `failed` になっており、Pythonアプリサービスの起動に失敗していた。

また、`status=200/CHDIR` と表示されているため、作業ディレクトリへの移動に失敗している可能性が高いと判断した。

---

### 3. myappのログ確認

```bash
journalctl -u myapp -n 30
```

確認結果。

```text
May 03 12:05:14 ubuntu-toki systemd[1]: Started myapp.service - My Python App Service.
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Changing to the requested working directory failed: No such file or directory
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Failed at step CHDIR spawning /usr/bin/python3: No such file or directory
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Main process exited, code=exited, status=200/CHDIR
May 03 12:05:14 ubuntu-toki systemd[1]: myapp.service: Failed with result 'exit-code'.
```

`journalctl` でも、指定された `WorkingDirectory` への移動に失敗していることが分かる。

このため、Pythonコマンド自体ではなく、`WorkingDirectory` の指定に問題がある可能性が高いと判断した。

---

### 4. ポート確認

```bash
ss -tulnp | grep -E '(:80|:3000)'
```

確認結果。

```text
tcp   LISTEN 0      511        0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=1280,fd=6))
```

80番ポートはNginxがLISTENしていた。

一方で、3000番ポートはLISTENしていなかったため、Pythonアプリは起動していなかった。

---

### 5. Pythonアプリ単体確認

```bash
curl http://127.0.0.1:3000
```

確認結果。

```text
curl: (7) Failed to connect to 127.0.0.1 port 3000 after 0 ms: Connection refused
```

Pythonアプリ単体にも接続できなかった。

3000番で待ち受けるプロセスが存在しないため、接続拒否されていた。

---

### 6. Nginx access.logの確認

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

確認結果。

```text
127.0.0.1 - - [03/May/2026:12:06:20 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
```

`access.log` に `/app/` へのアクセスと502が記録されていた。

このことから、リクエストはNginxまで届いていると判断した。

---

### 7. Nginx error.logの確認

```bash
sudo tail -n 30 /var/log/nginx/error.log
```

確認結果。

```text
2026/05/03 12:06:20 [error] 1283#1283: *27 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
```

Nginxはupstreamである `http://127.0.0.1:3000/` に接続しようとしていた。

しかし、3000番で待ち受けているプロセスがないため、`Connection refused` になっていた。

---

### 8. myapp.serviceのWorkingDirectory確認

```bash
grep -n "WorkingDirectory" /etc/systemd/system/myapp.service
```

確認結果。

```text
7:WorkingDirectory=/home/toki/myappp
```

`WorkingDirectory` が `/home/toki/myappp` になっており、想定している `/home/toki/myapp` と異なっていた。

末尾の `p` が1つ多く、typoの可能性があると判断した。

---

### 9. 実際のディレクトリ確認

```bash
ls -ld /home/toki/myapp
ls -ld /home/toki/myappp
```

確認結果。

```text
drwxr-xr-x 2 toki toki 4096 May 03 11:00 /home/toki/myapp
ls: cannot access '/home/toki/myappp': No such file or directory
```

`/home/toki/myapp` は存在していた。

一方で、`myapp.service` に指定されている `/home/toki/myappp` は存在しなかった。

このため、`WorkingDirectory` の指定ミスだと判断した。

---

## 切り分け

Nginxは `active (running)` であり、80番ポートもLISTENしていた。

そのため、Nginxサービス停止や80番ポートの待ち受け不備ではないと判断した。

一方で、`systemctl status myapp` では `myapp.service` が `failed` になっていた。

また、`journalctl -u myapp` では `Changing to the requested working directory failed` と表示されており、指定された作業ディレクトリへの移動に失敗していた。

ポート確認でも3000番はLISTENしておらず、`curl http://127.0.0.1:3000` でも `Connection refused` となった。

このことから、Pythonアプリは起動しておらず、3000番で待ち受けていない状態だと判断した。

Nginxの `access.log` には `/app/` へのアクセスと502が記録されており、リクエストはNginxまで届いていた。

Nginxの `error.log` では、`http://127.0.0.1:3000/` への接続に失敗していた。

さらに、`myapp.service` の `WorkingDirectory` を確認すると、`/home/toki/myappp` が指定されていた。

実際にディレクトリを確認すると、`/home/toki/myapp` は存在していたが、`/home/toki/myappp` は存在しなかった。

以上から、`myapp.service` の `WorkingDirectory` に存在しないディレクトリを指定していたことが原因だと判断した。

---

## 原因

`myapp.service` の `WorkingDirectory` に存在しないディレクトリ `/home/toki/myappp` を指定していた。

```ini
WorkingDirectory=/home/toki/myappp
```

そのため、systemdがサービス起動時に指定された作業ディレクトリへ移動できず、`myapp.service` の起動に失敗した。

結果として3000番ポートで待ち受けるPythonアプリが存在せず、Nginxがupstreamへ接続できなかったため、`502 Bad Gateway` が発生した。

---

## 解決

`myapp.service` の `WorkingDirectory` を、実際に存在する正しいディレクトリに修正する。

```bash
sudo nano /etc/systemd/system/myapp.service
```

修正前。

```ini
WorkingDirectory=/home/toki/myappp
```

修正後。

```ini
WorkingDirectory=/home/toki/myapp
```

設定変更をsystemdに反映する。

```bash
sudo systemctl daemon-reload
```

`myapp.service` を再起動する。

```bash
sudo systemctl restart myapp
```

---

## 解決後の確認

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

どちらも `index.html` の内容が返れば復旧完了。

---

## 学び

`WorkingDirectory` の指定ミスは、Pythonアプリのコード自体の問題ではなく、systemdがサービス起動前に作業ディレクトリへ移動できないことで発生する。

その結果、Pythonアプリは起動せず、3000番ポートもLISTENしない。

Nginxから見るとupstreamに接続できないため、`502 Bad Gateway` になる。

今回のように、`status=200/CHDIR` や `Changing to the requested working directory failed` が出ている場合は、`WorkingDirectory` の指定先が存在するか確認することが重要だと分かった。

502の切り分けでは、Nginxの状態だけでなく、systemdサービスの状態・systemdログ・待ち受けポート・サービスファイルの設定を順番に確認する必要がある。

---

## ExecStartミスとの違い

同じように `myapp.service` が `failed` になる場合でも、ログの見方で原因を分けられる。

```text
ExecStartミス
→ status=203/EXEC
→ 実行するコマンドやファイルパスが間違っている可能性が高い

WorkingDirectoryミス
→ status=200/CHDIR
→ 作業ディレクトリへの移動に失敗している可能性が高い
```

今回のケースでは、Pythonコマンド自体は正しかったが、`WorkingDirectory` に存在しない `/home/toki/myappp` を指定していたため、systemdが作業ディレクトリへ移動できず起動に失敗した。

# 03 502 Bad Gateway - systemd ExecStartミス

## 概要

Nginx経由で `/app/` にアクセスしたところ、`502 Bad Gateway` が発生した。

調査の結果、Nginx自体は起動しており、`proxy_pass` も3000番ポートを指定していた。

しかし、`myapp.service` の `ExecStart` に指定したPythonコマンドのパスが間違っていたため、systemdがPythonアプリを起動できず、3000番ポートで待ち受けるプロセスが存在しなかった。

その結果、Nginxがupstreamへ接続できず、502が発生していた。

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
- `myapp.service` の `ExecStart` に誤りがある

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
     Active: failed (Result: exit-code) since Sun 2026-05-03 11:35:41 JST; 2min ago
    Process: 1602 ExecStart=/usr/bin/pythn3 -m http.server 3000 --bind 127.0.0.1 (code=exited, status=203/EXEC)
   Main PID: 1602 (code=exited, status=203/EXEC)

May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Failed to execute /usr/bin/pythn3: No such file or directory
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Failed at step EXEC spawning /usr/bin/pythn3: No such file or directory
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Main process exited, code=exited, status=203/EXEC
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Failed with result 'exit-code'.
```

`myapp.service` は `failed` になっており、Pythonアプリサービスの起動に失敗していた。

また、`ExecStart` に指定された `/usr/bin/pythn3` が実行できていないことが分かった。

---

### 3. myappのログ確認

```bash
journalctl -u myapp -n 30
```

確認結果。

```text
May 03 11:35:41 ubuntu-toki systemd[1]: Started myapp.service - My Python App Service.
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Failed to execute /usr/bin/pythn3: No such file or directory
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Failed at step EXEC spawning /usr/bin/pythn3: No such file or directory
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Main process exited, code=exited, status=203/EXEC
May 03 11:35:41 ubuntu-toki systemd[1]: myapp.service: Failed with result 'exit-code'.
```

`journalctl` でも `/usr/bin/pythn3: No such file or directory` と出ていた。

このことから、systemdが `ExecStart` に指定されたコマンドを実行できていないと判断した。

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

一方で、3000番ポートはLISTENしていなかったため、Pythonアプリは待ち受けていなかった。

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

3000番で待ち受けるプロセスがないため、接続拒否されていた。

---

### 6. Nginx access.logの確認

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

確認結果。

```text
127.0.0.1 - - [03/May/2026:11:37:05 +0900] "GET /app/ HTTP/1.1" 502 157 "-" "curl/8.5.0"
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
2026/05/03 11:37:05 [error] 1283#1283: *22 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: _, request: "GET /app/ HTTP/1.1", upstream: "http://127.0.0.1:3000/", host: "localhost"
```

Nginxはupstreamである `http://127.0.0.1:3000/` に接続しようとしていた。

しかし、3000番で待ち受けているプロセスがないため、`Connection refused` になっていた。

---

### 8. myapp.serviceのExecStart確認

```bash
grep -n "ExecStart" /etc/systemd/system/myapp.service
```

確認結果。

```text
8:ExecStart=/usr/bin/pythn3 -m http.server 3000 --bind 127.0.0.1
```

`ExecStart` のPythonコマンドが `/usr/bin/pythn3` になっていた。

この時点で、Pythonコマンドのパスに綴りミスがある可能性が高いと判断した。

---

### 9. python3のフルパス確認

```bash
which python3
```

確認結果。

```text
/usr/bin/python3
```

正しいPythonコマンドのフルパスは `/usr/bin/python3` だった。

`myapp.service` の `ExecStart` に書かれていた `/usr/bin/pythn3` は誤りだと判断した。

---

## 切り分け

Nginxは `active (running)` であり、80番ポートもLISTENしていた。

そのため、Nginxサービス停止や80番ポートの待ち受け不備ではないと判断した。

一方で、`systemctl status myapp` では `myapp.service` が `failed` になっていた。

また、`journalctl -u myapp` でも `/usr/bin/pythn3: No such file or directory` と表示されていた。

ポート確認でも3000番はLISTENしておらず、`curl http://127.0.0.1:3000` でも `Connection refused` となった。

このことから、Pythonアプリが3000番で待ち受けていない状態だと判断した。

Nginxの `access.log` には `/app/` へのアクセスと502が記録されており、リクエストはNginxまで届いていた。

Nginxの `error.log` では、`http://127.0.0.1:3000/` への接続に失敗していた。

さらに、`myapp.service` の `ExecStart` を確認すると、`/usr/bin/pythn3` と書かれていた。

`which python3` の結果は `/usr/bin/python3` だったため、`ExecStart` に指定したPythonコマンドの綴りミスが原因だと判断した。

---

## 原因

`myapp.service` の `ExecStart` に指定したPythonコマンドのパスが誤っていた。

正しくは `/usr/bin/python3` だが、サービスファイルでは `/usr/bin/pythn3` となっていた。

```ini
ExecStart=/usr/bin/pythn3 -m http.server 3000 --bind 127.0.0.1
```

そのため、systemdがPythonを実行できず、`myapp.service` が起動失敗した。

結果として3000番ポートで待ち受けるプロセスが存在せず、Nginxがupstreamへ接続できなかったため、`502 Bad Gateway` が発生した。

---

## 解決

`myapp.service` の `ExecStart` を正しいパスに修正する。

```bash
sudo nano /etc/systemd/system/myapp.service
```

修正前。

```ini
ExecStart=/usr/bin/pythn3 -m http.server 3000 --bind 127.0.0.1
```

修正後。

```ini
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 127.0.0.1
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

`502 Bad Gateway` はNginx側のエラーとして表示されるが、原因がNginxにあるとは限らない。

今回のように、裏側のPythonアプリサービスがsystemdの `ExecStart` ミスで起動できていない場合も、Nginxから見るとupstreamに接続できないため502になる。

エラー画面だけでは原因を特定できないため、以下を順番に確認することが大切だと学んだ。

```text
1. Nginxの状態
2. myapp.serviceの状態
3. systemdのログ
4. 待ち受けポート
5. Pythonアプリ単体の応答
6. Nginxのaccess.log
7. Nginxのerror.log
8. systemd serviceファイルの設定
```

特に、`journalctl -u myapp` に出ていた `/usr/bin/pythn3: No such file or directory` は、`ExecStart` のパス誤りを特定する重要な手がかりになった。

---

## WorkingDirectoryミスとの違い

同じように `myapp.service` が `failed` になる場合でも、ログの見方で原因を分けられる。

```text
ExecStartミス
→ status=203/EXEC
→ 実行するコマンドやファイルパスが間違っている可能性が高い

WorkingDirectoryミス
→ status=200/CHDIR
→ 作業ディレクトリへの移動に失敗している可能性が高い
```

今回のケースでは、`WorkingDirectory` ではなく、`ExecStart` に指定した `/usr/bin/pythn3` という実行コマンドのパス誤りが原因だった。

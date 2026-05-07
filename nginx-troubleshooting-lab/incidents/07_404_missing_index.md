# 07 404 Not Found - index.html不足

## 概要

Nginx経由で `/app/` にアクセスしたところ、`404 Not Found` が発生した。

調査の結果、Nginx設定やPythonアプリサービス自体には問題はなく、Pythonアプリが配信しているディレクトリ内に `index.html` が存在しないことが原因だった。

今回はNginxが直接ファイルを配信しているのではなく、NginxがPython `http.server` へリバースプロキシしている構成だった。

そのため、404を返していたのはNginxではなく、upstreamであるPython `http.server` だった。

---

## 症状

`curl` でNginx経由のURLへアクセスしたところ、`404 Not Found` が表示された。

```bash
curl http://localhost/app/
```
## 期待される状態

Nginx経由でPythonアプリにアクセスし、index.html の内容が表示されること。

## 実際の状態

404 Not Found が返ってきた。

## 原因候補

考えられる原因は以下。

- Nginxの location 設定が間違っている
- Nginxの proxy_pass 先が間違っている
- Pythonアプリサービスが停止している
- Pythonアプリの WorkingDirectory が間違っている
- Pythonアプリが配信しているディレクトリに index.html が存在しない
## 確認したログ・コマンド
### 1. Pythonアプリ単体確認
```bash
curl http://localhost:3000
```
確認結果。
```txt
Error code: 404
Message: File not found.
```
Nginxを経由せずPythonアプリに直接アクセスしても404が返っていた。

このため、Nginx側ではなく、Pythonアプリ側、またはPythonアプリが配信しているディレクトリ内のファイル不足が原因の可能性が高いと判断した。

### 2. Pythonアプリサービスの状態確認
```bash
systemctl status myapp
```
確認結果。
```txt
Active: active (running)
```
Pythonアプリサービス自体は起動していた。

### 3. Nginx access.logの確認
```bash
sudo tail -n 5 /var/log/nginx/access.log
```
確認結果。
```txt
"GET /app/ HTTP/1.1" 404
```
/app/ へのアクセスはNginxまで届いており、404が返っていた。

### 4. Nginx error.logの確認
```bash
sudo tail -n 10 /var/log/nginx/error.log
```
確認結果。

今回の /app/ アクセスに関する新しいエラーは出ていない。

Nginxの error.log に新しいエラーは出ていなかった。

このため、Nginx自体の処理エラーではなく、upstreamであるPythonアプリから404が返っている可能性が高いと判断した。

### 5. Nginx設定ファイルの確認
```bash
sudo cat /etc/nginx/sites-enabled/default
```
確認結果。
```txt
location /app/ {
    proxy_pass http://127.0.0.1:3000/;
}
```
Nginxは /app/ へのアクセスを 127.0.0.1:3000 へ中継しており、proxy_pass 先は想定通りだった。

### 6. myapp.serviceの確認
```bash
sudo cat /etc/systemd/system/myapp.service
```
確認結果。
```txt
WorkingDirectory=/home/toki/myapp
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 127.0.0.1
```
Pythonアプリは /home/toki/myapp を作業ディレクトリとして起動していた。

つまり、このディレクトリ内のファイルが配信対象になる。

### 7. 配信ディレクトリの確認
```bash
ls /home/toki/myapp
```
確認結果。
```txt
about.html
README.txt
```
/home/toki/myapp に index.html が存在しなかった。

### 8. ディレクトリ権限の確認
```bash
ls -ld /home/toki/myapp
```
確認結果。
```txt
drwxr-xr-x 2 toki toki 4096 May 03 14:00 /home/toki/myapp
```
ディレクトリは存在しており、権限も問題なさそうだった。

そのため、権限ではなく、index.html が存在しないことが原因だと判断した。

## 切り分け

Pythonアプリサービスは active (running) で起動していた。

また、Nginx設定ファイルの proxy_pass も http://127.0.0.1:3000/ を向いており、想定通りだった。

一方で、curl http://localhost:3000 でPythonアプリに直接アクセスしても404が返った。

このため、Nginx側ではなく、Pythonアプリが配信している内容側に問題があると考えた。

myapp.service を確認すると、WorkingDirectory=/home/toki/myapp となっていた。

Pythonの簡易HTTPサーバは、起動時の作業ディレクトリ内のファイルを配信する。

そこで /home/toki/myapp の中身を確認したところ、about.html と README.txt は存在していたが、index.html は存在していなかった。

以上から、Pythonアプリが配信しているディレクトリ内に index.html が存在しないことが原因だと判断した。

## 原因

/home/toki/myapp に index.html が存在しなかったため、Pythonアプリが / に対応するファイルを返せず、404 Not Found が発生した。

Nginx経由でも同じPythonアプリへ中継しているため、curl http://localhost/app/ でも404が返った。

今回の404は、Nginxが直接返した404ではなく、upstreamであるPython http.server が返した404だった。

## 解決

/home/toki/myapp に index.html を作成する。
```bash
echo '<h1>Hello from Python App Service</h1>' > /home/toki/myapp/index.html
```
権限を確認する。
```bash
ls -l /home/toki/myapp/index.html
```
必要なら権限を変更する。
```bash
chmod 644 /home/toki/myapp/index.html
```
## 解決後の確認

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

- Nginx経由で404が返っていても、必ずしもNginx側が原因とは限らない。

今回のように、Pythonアプリに直接アクセスしても404が返る場合は、upstreamであるPythonアプリ側、特に配信ディレクトリやファイルの有無を確認する必要がある。

- Pythonの簡易HTTPサーバは、起動時の作業ディレクトリ内のファイルを配信する。

そのため、WorkingDirectory と実際のファイル配置をセットで確認することが大切だと分かった。

## 重要な違い

Nginxが直接ファイルを配信する場合と、NginxがPythonアプリへproxyしている場合では、同じように index.html が不足していても、返るステータスコードが変わる場合がある。
```txt
Nginxが直接ファイルを探す場合
Nginxが直接ファイルを探す
  ↓
ディレクトリはあるが index.html がない
  ↓
ディレクトリ一覧表示が無効
  ↓
403 Forbidden になりやすい
NginxがPythonへproxyしている場合
NginxがPython http.serverへproxyする
  ↓
Python http.server がファイルを探す
  ↓
Python側が File not found と判断
  ↓
404 Not Found になる
```
今回404が返ったのは、Nginxが直接ファイルを探していたからではなく、Python http.server が配信対象ディレクトリ内で index.html を見つけられなかったためである。

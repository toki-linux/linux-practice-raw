# 08 404 Not Found - alias設定ミス

## 概要

Nginxで `/images/test.html` にアクセスしたところ、`404 Not Found` が発生した。

調査の結果、Nginx設定ファイルの `alias` 指定で末尾の `/` が不足していたため、Nginxが想定とは異なるファイルパスを探していた。

その結果、存在しない `/var/www/imgtest.html` を探しに行き、404が発生していた。

---

## 症状

ブラウザまたは `curl` で以下にアクセスすると、`404 Not Found` が表示された。

```bash
curl http://localhost:8080/images/test.html
```
## 期待される状態

/var/www/img/test.html の内容が表示されること。

## 実際の状態

404 Not Found が返ってきた。

## 原因候補

考えられる原因は以下。

- 対象ファイルが存在しない
- Nginxの root または alias 設定が間違っている
- location の指定が間違っている
- alias の末尾 / が不足している
- Nginxが想定とは違うパスを探している
## 確認したログ・コマンド
### 1. Nginx経由でアクセスする
```bash
curl http://localhost:8080/images/test.html
```
確認結果。
“““txt
404 Not Found
```
/images/test.html にアクセスすると404が返った。

### 2. access.logで404を確認する
```bash
sudo tail -n 20 /var/log/nginx/access.log
```
確認結果。
```txt
"GET /images/test.html HTTP/1.1" 404
```
/images/test.html へのアクセスがNginxまで届き、404が返っていることを確認した。

### 3. error.logでNginxが探したパスを確認する
```bash
sudo tail -n 20 /var/log/nginx/error.log
```
確認結果。
```txt
open() "/var/www/imgtest.html" failed (2: No such file or directory)
```
このログから、Nginxが /var/www/img/test.html ではなく、/var/www/imgtest.html を探していることが分かった。

### 4. Nginx設定ファイルを確認する
```bash
sudo cat /etc/nginx/sites-enabled/default
```
確認した設定。
```txt
location /images/ {
    alias /var/www/img;
}
```
location /images/ に対して、alias /var/www/img; となっていた。

alias 側の末尾に / がないため、パスの結合が想定とずれていた。

### 5. 実際のファイルを確認する
```bash
ls -l /var/www/img/test.html
ls -l /var/www/imgtest.html
```
確認結果の例。
```txt
/var/www/img/test.html     は存在する
/var/www/imgtest.html      は存在しない
```
本来表示したいファイルは /var/www/img/test.html に存在していた。

しかし、Nginxは /var/www/imgtest.html を探していたため、404になっていた。

## 切り分け

access.log には /images/test.html へのアクセスと404が記録されていた。

このことから、リクエストはNginxまで届いていると判断した。

次に error.log を確認すると、以下のログが出ていた。

open() "/var/www/imgtest.html" failed (2: No such file or directory)

このログから、Nginxが実際に探しているファイルパスが /var/www/imgtest.html になっていることが分かった。

本来探してほしいファイルは /var/www/img/test.html だった。

そこでNginx設定ファイルを確認すると、以下のようになっていた。
```txt
location /images/ {
    alias /var/www/img;
}
```
location /images/ は末尾に / があるが、alias /var/www/img; は末尾に / がなかった。

そのため、Nginxがパスを結合する際に、/var/www/img と test.html がそのままつながり、/var/www/imgtest.html を探していた。

以上から、原因は alias の末尾 / 不足によるパス解釈ミスだと判断した。

## 原因

Nginx設定ファイルの alias 指定で、末尾の / が不足していた。

修正前。
```bash
location /images/ {
    alias /var/www/img;
}
```
この状態で /images/test.html にアクセスすると、Nginxは以下のように解釈する。
```txt
/images/ を取り除く
  ↓
test.html が残る
  ↓
alias の /var/www/img に連結する
  ↓
/var/www/imgtest.html を探す
```
その結果、存在しない /var/www/imgtest.html を探しに行き、404となった。

## 解決

Nginx設定ファイルを開く。
```bash
sudo nano /etc/nginx/sites-enabled/default
```
alias の末尾に / を追加する。

修正前。
```bash
location /images/ {
    alias /var/www/img;
}
```
修正後。
```bash
location /images/ {
    alias /var/www/img/;
}
```
Nginx設定ファイルの構文を確認する。
```bash
sudo nginx -t
```
設定を反映する。
```bash
sudo systemctl reload nginx
```
## 解決後の確認

再度アクセスする。
```bash
curl http://localhost:8080/images/test.html
```
test.html の内容が返れば解決。

Nginxが探すパスも、以下のようになる。
```txt
/images/test.html
  ↓
/var/www/img/test.html
```
## 再現手順

Nginx設定ファイルで、alias の末尾 / を外す。
```bash
location /images/ {
    alias /var/www/img;
}
```
その後、以下にアクセスする。
```bash
curl http://localhost:8080/images/test.html
```
error.log には、以下のようなログが出る。
```bash
open() "/var/www/imgtest.html" failed (2: No such file or directory)
```
## 学び

- alias は、location で一致した部分を置き換えるように使われる。

今回の場合、/images/test.html にアクセスすると、location /images/ に一致した /images/ の部分が取り除かれ、残りの test.html が alias で指定したパスの後ろにつながる。
```txt
location /images/
alias /var/www/img/
request /images/test.html
  ↓
/var/www/img/test.html
```
そのため、location が /images/ のように末尾 / を含む場合、alias 側も / で終える必要がある。

- alias の末尾 / が不足すると、以下のようにパスが不自然に連結される。
```txt
alias /var/www/img
request /images/test.html
  ↓
/var/www/imgtest.html
```
- 404が出た場合は、単に「ファイルがない」と考えるだけでなく、error.log を確認し、Nginxが実際にどのファイルパスを探しているかを見ることが重要だと分かった。

## 応用

404エラーでは、error.log にNginxが実際に探したファイルパスが表示されることがある。

そのため、404が発生した場合は以下を確認する。
```txt
1. リクエストしたURL
2. Nginxのlocation設定
3. root / alias の指定
4. error.logに出ている実際の探索パス
5. 実際にそのファイルが存在するか
```
特に alias を使う場合は、location と alias の末尾 / の有無に注意する必要がある。

# 09 404 Not Found - root設定ミス

## 概要

Nginxで `index.html` にアクセスしたところ、`404 Not Found` が発生した。

調査の結果、`index.html` 自体は存在していたが、Nginxの `root` 設定が実際のファイル配置と一致していなかった。

そのため、Nginxが想定とは別のディレクトリを探しに行き、ファイルを見つけられず404が発生していた。

---

## 症状

ブラウザまたは `curl` でアクセスすると、`404 Not Found` が表示された。

```bash
curl http://localhost/
```
## 期待される状態

index.html の内容が表示されること。

## 実際の状態

404 Not Found が返ってきた。

## 原因候補

考えられる原因は以下。

- index.html が存在しない
- Nginxの root 設定が間違っている
- URLと実際のファイル配置が一致していない
- Nginxが想定とは別のディレクトリを探している
- 設定変更後にNginxをreloadしていない
## 確認したログ・コマンド
### 1. Nginx経由でアクセスする
```bash
curl http://localhost/
```
確認結果。
```txt
404 Not Found
```
/ にアクセスすると404が返った。

### 2. access.logで404を確認する
```bash
sudo tail -n 20 /var/log/nginx/access.log
```
確認結果の例。
```txt
"GET / HTTP/1.1" 404
```
リクエストはNginxまで届いており、Nginxが404を返していることを確認した。

### 3. Nginx設定ファイルのrootを確認する
```bash
grep -n "root" /etc/nginx/sites-enabled/default
```
確認結果の例。
```txt
root /var/www/test;
```
Nginxの root が /var/www/test になっていた。

### 4. 実際のファイル配置を確認する
```bash
ls -l /var/www/html/index.html
ls -l /var/www/test/index.html
```
確認結果の例。
```txt
/var/www/html/index.html      は存在する
/var/www/test/index.html      は存在しない
```
実際には /var/www/html/index.html が存在していた。

しかし、Nginxは root /var/www/test; の設定により、/var/www/test/index.html を探していた。

## 切り分け

access.log に404が記録されていたため、リクエストはNginxまで届いていると判断した。

次に、実際のファイル配置を確認したところ、/var/www/html/index.html は存在していた。

しかし、Nginx設定ファイルを確認すると、root が以下のようになっていた。
```bash
root /var/www/test;
```
この設定の場合、Nginxは / へのアクセスに対して以下のファイルを探す。
```bash
/var/www/test/index.html
```
一方で、実際に存在していたファイルは以下だった。
```bash
/var/www/html/index.html
```
このことから、ファイル自体が存在しないのではなく、Nginxの root 設定と実際のファイル配置が一致していないことが原因だと判断した。

## 原因

Nginxの root 設定が、実際のファイル配置と一致していなかった。

実際のファイル配置。
```bash
/var/www/html/index.html
```
誤っていたNginx設定。
```bash
root /var/www/test;
```
この場合、Nginxは以下を探す。
```bash
/var/www/test/index.html
```
その場所に index.html が存在しないため、404 Not Found になった。

## 解決

Nginx設定ファイルの root を、実際にファイルが存在するパスに修正する。
```bash
sudo nano /etc/nginx/sites-enabled/default
```
修正前。
```bash
root /var/www/test;
```
修正後。
```bash
root /var/www/html;
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
curl http://localhost/
```
index.html の内容が返れば解決。

## 再現手順

Nginx設定ファイルの root を、実際のファイル配置と違う場所に変更する。

例：
```bash
root /var/www/test;
```
設定変更後、Nginxを再読み込みする。
```bash
sudo nginx -t
sudo systemctl reload nginx
```
その後、以下にアクセスする。
```bash
curl http://localhost/
```
/var/www/test/index.html が存在しない場合、404が返る。

## 学び

- 404 Not Found は、単にファイルが存在しない場合だけでなく、Nginxが探している場所と実際のファイル配置がズレている場合にも発生する。

- 今回の場合、index.html は存在していたが、Nginxの root が別のディレクトリを指していたため、Nginxは存在しない /var/www/test/index.html を探していた。

そのため、404が出た場合は、ファイルの有無だけでなく、以下をセットで確認することが重要だと分かった。
```txt
1. アクセスしたURL
2. Nginxのlocation設定
3. Nginxのroot設定
4. Nginxが実際に探すファイルパス
5. 実際のファイル配置
```
## root設定の考え方

root は、リクエストされたURLのパスを、指定したディレクトリの後ろにつなげてファイルを探す。

例：
```txt
root /var/www/html;

この状態で /index.html にアクセスすると、Nginxは以下を探す。

/var/www/html/index.html

一方で、root が以下のように間違っていると、

root /var/www/test;

Nginxは以下を探す。

/var/www/test/index.html
```
このように、root の指定先がズレると、実際にはファイルが存在していてもNginxからは見つけられず、404になる。

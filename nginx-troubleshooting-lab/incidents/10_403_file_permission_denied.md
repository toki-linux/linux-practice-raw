# 10 403 Forbidden - ファイル権限不足

## 概要

Nginxで `index.html` にアクセスしたところ、`403 Forbidden` が発生した。

調査の結果、`index.html` 自体は存在していたが、ファイルの権限が不足しており、Nginxの実行ユーザーである `www-data` がファイルを読み取れない状態だった。

そのため、Nginxがファイルを返すことができず、403が発生していた。

---

## 症状

ブラウザまたは `curl` でアクセスすると、`403 Forbidden` が表示された。

```bash
curl http://localhost/
```
## 期待される状態

/var/www/html/index.html の内容が表示されること。

## 実際の状態

403 Forbidden が返ってきた。

## 原因候補

考えられる原因は以下。

- Nginxの設定でアクセスが拒否されている
- index.html が存在しない
- index.html の読み取り権限が不足している
- 親ディレクトリに実行権限がない
- Nginxの実行ユーザーが対象ファイルを読めない
- deny all; のようなアクセス制御が設定されている
## 確認したログ・コマンド
### 1. Nginx経由でアクセスする
```bash
curl http://localhost/
```
確認結果。
```txt
403 Forbidden
```
Nginx経由でアクセスすると403が返った。

### 2. access.logで403を確認する
```basj
sudo tail -n 20 /var/log/nginx/access.log
```
確認結果の例。
```txt
"GET / HTTP/1.1" 403
```
リクエストはNginxまで届いており、Nginxが403を返していることを確認した。

### 3. error.logで permission denied を確認する
```bash
sudo tail -n 20 /var/log/nginx/error.log
```
確認結果の例。
```txt
open() "/var/www/html/index.html" failed (13: Permission denied)
```
このログから、Nginxが /var/www/html/index.html を開こうとしたが、権限不足で拒否されたことが分かる。

### 4. ファイルの権限を確認する
```bash
ls -l /var/www/html/index.html
```
確認結果の例。
```txt
-rw------- 1 root root 32 May 03 14:30 /var/www/html/index.html
```
index.html の権限が 600 になっていた。

この場合、所有者である root は読み書きできるが、Nginxの実行ユーザーである www-data は読み取れない。

### 5. ディレクトリの権限を確認する
```bash
ls -ld /var/www/html
```
確認結果の例。
```txt
drwxr-xr-x 2 root root 4096 May 03 14:30 /var/www/html
```
ディレクトリには実行権限 x があり、ディレクトリをたどることはできる状態だった。

そのため、今回の主な原因はディレクトリ権限ではなく、index.html の読み取り権限不足だと判断した。

## 切り分け

access.log には403が記録されていたため、リクエストはNginxまで届いていると判断した。

次に error.log を確認すると、以下のようなログが出ていた。
```bash
open() "/var/www/html/index.html" failed (13: Permission denied)
```
このログから、Nginxが対象ファイルを開こうとしたが、権限不足で拒否されたことが分かった。

そこで /var/www/html/index.html の権限を確認したところ、権限が 600 になっていた。
```bash
-rw------- 1 root root ... index.html
```
この状態では、所有者である root 以外はファイルを読み取れない。

Nginxは通常、www-data ユーザーで動作しているため、www-data が index.html を読み取れず、403になったと判断した。

また、Webサーバがファイルを返すには、ファイル自体の読み取り権限だけでなく、親ディレクトリをたどるための実行権限 x も必要になる。

今回はディレクトリ権限には問題がなく、ファイル権限が主な原因だった。

## 原因

/var/www/html/index.html の権限が 600 になっており、Nginxの実行ユーザーである www-data が読み取れなかった。
```bash
-rw------- 1 root root ... index.html
```
600 は、所有者のみが読み書きできる権限である。

そのため、所有者ではない www-data は index.html を読み取れず、Nginxがファイルを返せなかった。

結果として、403 Forbidden が発生した。

## 解決

index.html に、Nginxの実行ユーザーから読み取れる権限を付与する。
```bash
sudo chmod 644 /var/www/html/index.html
```
修正後の権限を確認する。
```bash
ls -l /var/www/html/index.html
```
## 想定される状態。
```bash
-rw-r--r-- 1 root root ... index.html
```
644 にすることで、所有者は読み書きでき、グループとその他ユーザーは読み取りできる。

これにより、Nginxの実行ユーザーである www-data からもファイルを読み取れるようになる。

ディレクトリ権限も不足している場合

ファイルの読み取り権限だけでなく、親ディレクトリの実行権限 x も必要になる。

たとえば、ディレクトリ権限が不足している場合は、以下のように修正する。
```bash
sudo chmod 755 /var/www/html
```
ディレクトリの x は、そのディレクトリの中へ入るために必要な権限である。

Webサーバが /var/www/html/index.html を返すには、以下の両方が必要になる。
```txt
/var/www/html/       → ディレクトリをたどる実行権限 x
index.html           → ファイルを読む読み取り権限 r
解決後の確認
```
再度アクセスする。
```bash
curl http://localhost/
```
index.html の内容が返れば解決。

## 再現手順

index.html の権限を 600 に変更する。
```bash
sudo chmod 600 /var/www/html/index.html
```
その後、ブラウザまたは curl でアクセスする。
```bash
curl http://localhost/
```
Nginxの実行ユーザーが index.html を読み取れないため、403が返る。

## 学び

- Webサーバのアクセス可否は、Nginxの設定だけでなく、Linuxのファイル・ディレクトリ権限にも大きく影響される。

今回のように、index.html が存在していても、Nginxの実行ユーザーが読み取れなければ 403 Forbidden になる。

特に確認すべきポイントは以下。
```txt
1. 対象ファイルが存在するか
2. ファイルに読み取り権限があるか
3. 親ディレクトリに実行権限があるか
4. Nginxの実行ユーザーがそのファイルへ到達できるか
5. error.log に permission denied が出ているか
```
- error.log に Permission denied が出ている場合は、Nginx設定だけでなく、ファイルやディレクトリの権限不足を疑う必要がある。

## 404との違い

404 Not Found は、Nginxが探した場所にファイルが存在しない場合に発生する。

一方で、今回のような 403 Forbidden は、ファイルは存在しているが、Nginxが権限不足で読み取れない場合に発生する。
```txt
404 Not Found
→ 探した場所にファイルがない

403 Forbidden
→ ファイルはあるが、権限などの理由でアクセスできない
```
今回のケースでは、index.html 自体は存在していたが、ファイル権限が 600 だったため、Nginxの実行ユーザーが読み取れず403になった。

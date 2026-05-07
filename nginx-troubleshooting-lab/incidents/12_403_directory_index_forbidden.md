# 12 403 Forbidden - directory index is forbidden

## 概要

Nginxでドキュメントルートにアクセスしたところ、`403 Forbidden` が発生した。

調査の結果、`/var/www/html/` ディレクトリ自体にはアクセスできていたが、表示するための `index.html` が存在しなかった。

また、Nginxのディレクトリ一覧表示機能である `autoindex` が無効だったため、ディレクトリの中身を一覧表示できず、`403 Forbidden` が発生していた。

---

## 症状

ブラウザまたは `curl` でアクセスすると、`403 Forbidden` が表示された。

```bash
curl http://localhost:8080/
```

---

## 期待される状態

`/var/www/html/index.html` の内容が表示されること。

---

## 実際の状態

`403 Forbidden` が返ってきた。

---

## 原因候補

考えられる原因は以下。

- `index.html` が存在しない
- Nginxの `index` ディレクティブで指定されたファイルが存在しない
- ディレクトリ一覧表示である `autoindex` が無効になっている
- ファイルまたはディレクトリの権限が不足している
- Nginxの `root` 設定が間違っている
- Nginx設定でアクセス拒否されている

---

## 確認したログ・コマンド

### 1. Nginx経由でアクセスする

```bash
curl http://localhost:8080/
```

確認結果。

```text
403 Forbidden
```

Nginx経由でアクセスすると403が返った。

---

### 2. access.logで403を確認する

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

確認結果の例。

```text
"GET / HTTP/1.1" 403
```

リクエストはNginxまで届いており、Nginxが403を返していることを確認した。

---

### 3. error.logで原因を確認する

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

確認結果。

```text
2026/04/28 17:24:09 [error] 1454#1454: *3 directory index of "/var/www/html/" is forbidden, client: 10.0.2.2, server: _, request: "GET / HTTP/1.1", host: "localhost:8080"
```

`directory index of "/var/www/html/" is forbidden` と出ていた。

このログから、Nginxは `/var/www/html/` までは到達できているが、ディレクトリ一覧表示が禁止されているため403になっていると判断した。

---

### 4. ドキュメントルートの権限を確認する

```bash
ls -ld /var/www/html
```

確認結果。

```text
drwxrwxr-x 2 toki toki 4096 Apr 28 17:17 /var/www/html
```

`others` にも `r-x` があるため、Nginx実行ユーザーは `/var/www/html/` ディレクトリをたどることができる。

そのため、今回の403はディレクトリ権限不足ではないと判断した。

---

### 5. ドキュメントルート配下のファイルを確認する

```bash
ls -l /var/www/html
```

確認する内容。

```text
index.html が存在するか
```

今回、`/var/www/html/` 配下に `index.html` が存在しない状態だった。

---

### 6. Nginx設定ファイルを確認する

```bash
sudo cat /etc/nginx/sites-enabled/default
```

確認する内容。

```nginx
root /var/www/html;
index index.html index.htm index.nginx-debian.html;
```

Nginxは `/var/www/html/` をドキュメントルートとして使用し、`index.html` などのインデックスファイルを探す設定になっている。

しかし、該当するindexファイルが存在しない場合、Nginxはディレクトリ一覧を表示しようとする。

通常、`autoindex` は無効のため、ディレクトリ一覧を表示できず403になる。

---

## 切り分け

`access.log` には403が記録されていたため、リクエストはNginxまで届いていると判断した。

次に `error.log` を確認すると、以下のログが出ていた。

```text
directory index of "/var/www/html/" is forbidden
```

このログから、Nginxは `/var/www/html/` というディレクトリまでは到達できていることが分かった。

しかし、表示するための `index.html` が存在せず、さらにディレクトリ一覧表示も禁止されていたため、403になっていた。

`ls -ld /var/www/html` を確認すると、以下の状態だった。

```text
drwxrwxr-x 2 toki toki 4096 Apr 28 17:17 /var/www/html
```

`others` にも `r-x` があるため、Nginx実行ユーザーはディレクトリをたどることができる。

そのため、今回の403はLinuxのディレクトリ権限不足ではなく、`index.html` が存在しないことと、`autoindex` が無効であることが原因だと判断した。

---

## 原因

ドキュメントルートである `/var/www/html/` 配下に、表示するための `index.html` が存在しなかった。

Nginxはディレクトリにアクセスされた場合、まず `index` ディレクティブで指定されたファイルを探す。

例：

```nginx
index index.html index.htm index.nginx-debian.html;
```

しかし、該当するindexファイルが存在しない場合、Nginxはディレクトリ一覧を表示しようとする。

今回、ディレクトリ一覧表示である `autoindex` は無効だったため、Nginxはディレクトリの中身を表示できず、`403 Forbidden` を返した。

```text
/var/www/html/ までは到達できた
  ↓
index.html がない
  ↓
ディレクトリ一覧を表示しようとする
  ↓
autoindex が無効
  ↓
directory index is forbidden
  ↓
403 Forbidden
```

---

## 解決

解決方法は主に2つある。

---

### 方法1. index.html を配置する

通常はこちらの方法を使う。

`/var/www/html/` 配下に `index.html` を作成する。

```bash
echo '<h1>Hello from Nginx</h1>' | sudo tee /var/www/html/index.html
```

権限を確認する。

```bash
ls -l /var/www/html/index.html
```

必要に応じて、Nginx実行ユーザーが読める権限にする。

```bash
sudo chmod 644 /var/www/html/index.html
```

---

### 方法2. autoindex を有効にする

検証用途でディレクトリ一覧を表示したい場合は、Nginx設定で `autoindex on;` を設定する。

```nginx
location / {
    autoindex on;
}
```

設定ファイルの構文を確認する。

```bash
sudo nginx -t
```

設定を反映する。

```bash
sudo systemctl reload nginx
```

ただし、実運用ではディレクトリ一覧を公開すると不要なファイルまで見える可能性があるため、基本的には `index.html` を配置する方が安全。

---

## 解決後の確認

再度アクセスする。

```bash
curl http://localhost:8080/
```

`index.html` の内容が返れば解決。

---

## 再現手順

`/var/www/html/` 配下のindexファイルを移動または削除する。

```bash
sudo mv /var/www/html/index.html /tmp/
```

Nginxの `autoindex` が無効な状態で、以下にアクセスする。

```bash
curl http://localhost:8080/
```

`index.html` がなく、ディレクトリ一覧表示も禁止されているため、403が返る。

---

## 学び

Nginxはディレクトリにアクセスされた場合、まず `index.html` などのインデックスファイルを探す。

インデックスファイルが存在しない場合、次にディレクトリ一覧を表示できるかを確認する。

しかし、通常は `autoindex` が無効になっているため、ディレクトリ一覧は表示されない。

その結果、`directory index is forbidden` となり、`403 Forbidden` が返る。

---

## 権限不足の403との違い

今回の403は、Linuxのファイル・ディレクトリ権限不足ではない。

`ls -ld /var/www/html` の結果は以下だった。

```text
drwxrwxr-x 2 toki toki 4096 Apr 28 17:17 /var/www/html
```

`others` にも `r-x` があるため、Nginx実行ユーザーはディレクトリに入ることができる。

しかし、`index.html` が存在せず、ディレクトリ一覧表示も禁止されていたため、403になった。

```text
権限不足の403
→ ファイルやディレクトリにアクセスする権限がない

directory index is forbidden の403
→ ディレクトリには到達できるが、表示するindexファイルがなく、一覧表示も禁止されている
```

---

## 404との違い

`404 Not Found` は、Nginxが探した場所にファイルやパスが存在しない場合に発生する。

一方で、今回の `403 Forbidden` は、Nginxが `/var/www/html/` というディレクトリには到達できているが、そのディレクトリをどう表示するか決められないために発生している。

```text
404 Not Found
→ 探したファイルやパスが存在しない

403 Forbidden
→ ディレクトリには到達できたが、indexファイルがなく、一覧表示も禁止されている
```

今回の `error.log` の `directory index of "/var/www/html/" is forbidden` は、Nginxがディレクトリまでは見つけていることを示している。

---

## 応用

`403 Forbidden` が出た場合は、原因を1つに決めつけず、以下を順番に確認する。

```text
1. access.logで403を確認する
2. error.logに permission denied が出ているか確認する
3. error.logに directory index is forbidden が出ているか確認する
4. 対象ファイルが存在するか確認する
5. index.html が存在するか確認する
6. ディレクトリ権限を確認する
7. autoindex の設定を確認する
```

`permission denied` なら権限不足を疑う。

`directory index is forbidden` なら、indexファイル不足とautoindex無効を疑う。

# 13 403 Forbidden - index指定ミス

## 概要

Nginxで `/` にアクセスしたところ、`403 Forbidden` が発生した。

調査の結果、ドキュメントルートである `/var/www/html/` は正しく、表示したいファイル `stat.html` も存在していた。

しかし、Nginxの `index` ディレクティブには `index.html` のみが指定されており、`stat.html` は指定されていなかった。

そのため、`/` にアクセスした時にNginxが表示するindexファイルを見つけられず、さらにディレクトリ一覧表示も無効だったため、403が発生した。

---

## 症状

ブラウザまたは `curl` で `/` にアクセスすると、`403 Forbidden` が表示された。

```bash
curl http://localhost/
```

---

## 期待される状態

`/var/www/html/stat.html` の内容が表示されること。

---

## 実際の状態

`403 Forbidden` が返ってきた。

---

## 原因候補

考えられる原因は以下。

- `root` の指定が間違っている
- 表示したいファイルが存在しない
- ファイルやディレクトリの権限が不足している
- `index` ディレクティブに表示したいファイル名が指定されていない
- `index.html` が存在しない
- `autoindex` が無効になっている

---

## 確認したログ・コマンド

### 1. Nginx経由でアクセスする

```bash
curl http://localhost/
```

確認結果。

```text
403 Forbidden
```

`/` にアクセスすると403が返った。

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

### 3. error.logを確認する

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

確認結果の例。

```text
directory index of "/var/www/html/" is forbidden
```

このログから、Nginxは `/var/www/html/` というディレクトリまでは到達しているが、表示できるindexファイルが見つからず、ディレクトリ一覧表示も禁止されているため403になっていると判断した。

---

### 4. Nginx設定ファイルのrootを確認する

```bash
grep -n "root" /etc/nginx/sites-enabled/default
```

確認結果の例。

```nginx
root /var/www/html;
```

`root` は `/var/www/html` を指しており、ドキュメントルートの指定は想定通りだった。

---

### 5. Nginx設定ファイルのindex指定を確認する

```bash
grep -n "index" /etc/nginx/sites-enabled/default
```

確認結果の例。

```nginx
index index.html;
```

`index` に指定されているのは `index.html` のみだった。

---

### 6. 実際のファイル配置を確認する

```bash
ls -l /var/www/html
```

確認結果の例。

```text
-rw-r--r-- 1 root root  ... stat.html
```

`/var/www/html/stat.html` は存在していた。

しかし、`index` に指定されている `index.html` は存在していなかった。

---

## 切り分け

`access.log` には403が記録されていたため、リクエストはNginxまで届いていると判断した。

次に `error.log` を確認すると、以下のようなログが出ていた。

```text
directory index of "/var/www/html/" is forbidden
```

このログから、Nginxは `/var/www/html/` というディレクトリまでは到達しているが、表示するindexファイルを見つけられず、ディレクトリ一覧表示もできない状態だと分かった。

`root` 設定を確認すると、以下のようになっていた。

```nginx
root /var/www/html;
```

このため、Nginxが見ているドキュメントルートは想定通りだった。

次に `/var/www/html` の中身を確認すると、`stat.html` は存在していた。

しかし、Nginxの `index` ディレクティブには `index.html` のみが指定されていた。

```nginx
index index.html;
```

`/` にアクセスした場合、Nginxは `root` 配下で `index` に指定されたファイルを探す。

今回の場合、Nginxは以下を探していた。

```text
/var/www/html/index.html
```

しかし、実際に存在していたのは以下だった。

```text
/var/www/html/stat.html
```

そのため、表示したい `stat.html` は存在していても、`index` に指定されていないため自動表示されなかった。

以上から、原因は `index` ディレクティブに `stat.html` が指定されていないことだと判断した。

---

## 原因

Nginxの `index` ディレクティブに、実際に表示したい `stat.html` が指定されていなかった。

修正前。

```nginx
index index.html;
```

この状態で `/` にアクセスすると、Nginxは以下のファイルを探す。

```text
/var/www/html/index.html
```

しかし、`index.html` は存在せず、存在していたのは `stat.html` だった。

```text
/var/www/html/stat.html
```

そのため、Nginxは表示できるindexファイルを見つけられなかった。

さらに、ディレクトリ一覧表示である `autoindex` も無効だったため、`403 Forbidden` が発生した。

---

## 解決

Nginx設定ファイルの `index` に `stat.html` を追加する。

```bash
sudo nano /etc/nginx/sites-enabled/default
```

修正前。

```nginx
index index.html;
```

修正後。

```nginx
index index.html stat.html;
```

Nginx設定ファイルの構文を確認する。

```bash
sudo nginx -t
```

設定を反映する。

```bash
sudo systemctl reload nginx
```

---

## 解決後の確認

再度アクセスする。

```bash
curl http://localhost/
```

`stat.html` の内容が返れば解決。

---

## 再現手順

`/var/www/html/` に `stat.html` を配置する。

```bash
echo '<h1>Status Page</h1>' | sudo tee /var/www/html/stat.html
```

`index.html` が存在しない状態にする。

```bash
sudo rm -f /var/www/html/index.html
```

Nginx設定ファイルの `index` を `index.html` のみにする。

```nginx
index index.html;
```

設定を反映する。

```bash
sudo nginx -t
sudo systemctl reload nginx
```

その後、以下にアクセスする。

```bash
curl http://localhost/
```

`stat.html` は存在するが、`index` に指定されていないため、Nginxは表示できるindexファイルを見つけられず403になる。

---

## 学び

`root` が正しくても、`/` にアクセスした時に表示されるファイルは `index` ディレクティブによって決まる。

存在するファイルがあっても、`index` に指定されていなければ自動表示されない。

今回の場合、`stat.html` は存在していたが、Nginxの `index` 設定には `index.html` しか指定されていなかった。

そのため、Nginxは `stat.html` を自動では表示せず、`index.html` を探した。

`index.html` が存在せず、さらに `autoindex` も無効だったため、`403 Forbidden` になった。

---

## directory index is forbidden との関係

今回のエラーは、最終的には `directory index is forbidden` と同じ流れで403になっている。

```text
/ にアクセス
  ↓
Nginxが root 配下を見る
  ↓
index ディレクティブに指定されたファイルを探す
  ↓
index.html が存在しない
  ↓
autoindex が無効
  ↓
directory index is forbidden
  ↓
403 Forbidden
```

ただし、原因の入口は少し違う。

```text
12_403_directory_index_forbidden
→ indexファイル自体が存在しない

13_403_index_directive_mismatch
→ 表示したいファイルは存在するが、indexに指定されていない
```

---

## 404との違い

`404 Not Found` は、Nginxが探したファイルやパス自体が存在しない場合に発生する。

一方で、今回の403は、Nginxが `/var/www/html/` というディレクトリには到達できているが、`index` に指定された表示用ファイルがなく、ディレクトリ一覧表示も禁止されているために発生している。

```text
404 Not Found
→ 探したファイルやパスが存在しない

403 Forbidden
→ ディレクトリには到達できたが、表示できるindexファイルがなく、一覧表示も禁止されている
```

---

## 応用

403が出た場合は、権限だけでなく、`index` の指定も確認する。

確認するポイントは以下。

```text
1. root は正しいか
2. 表示したいファイルは存在するか
3. index にそのファイル名が指定されているか
4. index.html が存在するか
5. autoindex は有効か無効か
6. error.log に directory index is forbidden が出ているか
```

`root` が正しく、ファイルも存在しているのに `/` で表示されない場合は、`index` ディレクティブの指定ミスを疑う。

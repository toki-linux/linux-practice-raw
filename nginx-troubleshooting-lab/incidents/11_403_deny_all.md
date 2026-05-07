# 11 403 Forbidden - deny allによるアクセス拒否

## 概要

Nginxでアクセスしたところ、`403 Forbidden` が発生した。

調査の結果、Nginx設定ファイル内に `deny all;` が設定されており、すべてのアクセスが拒否されていた。

そのため、ファイル権限やファイルの有無ではなく、Nginxのアクセス制御設定によって403が発生していた。

---

## 症状

ブラウザまたは `curl` でアクセスすると、`403 Forbidden` が表示された。

```bash
curl http://localhost/
```

---

## 期待される状態

`index.html` の内容が表示されること。

---

## 実際の状態

`403 Forbidden` が返ってきた。

---

## 原因候補

考えられる原因は以下。

- Nginx設定でアクセスが拒否されている
- `deny all;` が設定されている
- ファイル権限が不足している
- ディレクトリ権限が不足している
- `index.html` が存在しない
- ディレクトリ一覧表示が禁止されている

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

### 3. error.logを確認する

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

確認結果の例。

```text
access forbidden by rule
```

このログから、ファイルが存在しないのではなく、Nginxの設定ルールによってアクセスが拒否されている可能性があると判断した。

---

### 4. Nginx設定ファイルを確認する

```bash
sudo grep -n "deny" /etc/nginx/sites-enabled/default
```

確認結果の例。

```text
deny all;
```

Nginx設定ファイル内に `deny all;` が設定されていた。

---

### 5. ファイル権限も確認する

```bash
ls -l /var/www/html/index.html
ls -ld /var/www/html
```

確認結果の例。

```text
-rw-r--r-- 1 root root ... /var/www/html/index.html
drwxr-xr-x 2 root root ... /var/www/html
```

ファイルとディレクトリの権限には大きな問題がなかった。

そのため、Linuxのファイル権限ではなく、Nginx設定の `deny all;` によるアクセス拒否が原因だと判断した。

---

## 切り分け

`access.log` には403が記録されていたため、リクエストはNginxまで届いていると判断した。

次に `error.log` を確認すると、`access forbidden by rule` のようなログが出ていた。

これは、Nginxの設定ルールによってアクセスが拒否されていることを示している。

ファイル権限も確認したが、`index.html` は読み取り可能で、ディレクトリにも実行権限があった。

そこでNginx設定ファイルを確認すると、以下の設定が見つかった。

```nginx
deny all;
```

この設定により、すべてのアクセスが拒否されていた。

以上から、原因はファイル権限不足ではなく、Nginxの `deny all;` によるアクセス拒否だと判断した。

---

## 原因

Nginx設定ファイル内に `deny all;` が設定されていた。

```nginx
deny all;
```

`deny all;` は、すべてのアクセスを拒否する設定である。

そのため、対象のファイルが存在していても、ファイル権限に問題がなくても、Nginxがアクセスを拒否し、`403 Forbidden` が発生した。

---

## 解決

Nginx設定ファイルを開く。

```bash
sudo nano /etc/nginx/sites-enabled/default
```

`deny all;` を削除、またはコメントアウトする。

修正前。

```nginx
deny all;
```

修正後。

```nginx
# deny all;
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

`index.html` の内容が返れば解決。

---

## 再現手順

Nginx設定ファイルに `deny all;` を追加する。

例：

```nginx
location / {
    deny all;
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

その後、以下にアクセスする。

```bash
curl http://localhost/
```

Nginx設定によりアクセスが拒否され、403が返る。

---

## 学び

`403 Forbidden` は、Linuxのファイル権限不足だけで発生するわけではない。

今回のように、Nginx設定ファイル内の `deny all;` によって、意図的にアクセスが拒否されている場合もある。

`deny all;` はファイルの有無や権限に関係なく、Nginxの設定としてアクセスを拒否する。

そのため、403が出た場合は、以下を分けて確認する必要がある。

```text
1. ファイルは存在するか
2. ファイル権限は正しいか
3. ディレクトリ権限は正しいか
4. Nginx設定で deny all; が入っていないか
5. error.log に access forbidden by rule が出ていないか
```

---

## permission deniedとの違い

同じ403でも、原因によって見るべき場所が変わる。

```text
permission denied
→ Linuxのファイル・ディレクトリ権限不足を疑う

access forbidden by rule
→ Nginxの deny all; などアクセス制御設定を疑う
```

今回のケースでは、ファイル権限ではなく、Nginx設定の `deny all;` によってアクセスが拒否されていた。

---

## 404との違い

`404 Not Found` は、Nginxが探したファイルやパスが存在しない場合に発生する。

一方で、今回の `403 Forbidden` は、ファイルやディレクトリが存在していても、Nginx設定によってアクセスが拒否されている場合に発生する。

```text
404 Not Found
→ 探したファイルやパスが存在しない

403 Forbidden
→ ファイルやパスは存在していても、アクセスが許可されていない
```

今回のように `deny all;` が設定されている場合、対象ファイルが存在していてもNginxがアクセスを拒否する。

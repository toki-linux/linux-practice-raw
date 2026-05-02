## 502 Bad-gateway まとめ

## 概要
502 Bad Gateway は「nginxは正常だが、転送先（upstream）に接続できない」場合に発生するエラー。

---

## 発生パターン

### パターン①：サーバが起動していない

#### 原因
nginxがリクエストを転送している先（Pythonサーバなど）が起動していない

#### ログ
```text
connect() failed (111: Connection refused) while connecting to upstream
解決
python3 -m http.server 3001
パターン②：ポート番号の不一致
原因

nginxのproxy_passで指定したポートと、実際に起動しているポートが一致していない

ログ
connect() failed (111: Connection refused)
解決

どちらかを合わせる：

python3 -m http.server 3001

または

proxy_pass http://127.0.0.1:3001;
パターン③：ポートはあるがlistenしていない
原因

対象サービスは起動しているが、指定ポートで待ち受けていない

確認
ss -tulnp | grep 3001
解決

サービスを正しいポートで起動する

ログの特徴
connect() failed (111: Connection refused)

👉 upstreamに接続できていない

切り分け手順
① upstreamのポートを確認
② プロセスが動いているか確認
③ ポートがLISTENしているか確認
④ nginx設定のproxy_passを確認
systemctl status nginx
ps aux | grep python
ss -tulnp | grep ポート番号
学び
502は「nginxではなく、その先の問題」
エラーコード111は「接続拒否」
ポートとプロセスの対応関係が重要

---

# 🔥 フィードバック

## 👍 良い
- パターン化できてる → 強い
- ①②の関係理解してる → 本質

---

## ⚠️ 伸びるポイント

### 「ログ＝意味」を結びつける

```text
111 → 接続拒否 → サーバいない

👉 これ言えると一気に強い

🎯 一言
502は「繋ぎ先が死んでる」





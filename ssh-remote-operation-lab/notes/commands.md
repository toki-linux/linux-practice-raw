# SSHリモート操作で使用したコマンドまとめ

## 目的

このファイルでは、SSH接続・公開鍵認証・scpによるファイル転送・ログ確認・ポート確認で使用したコマンドを整理する。

各コマンドの意味を簡単にまとめ、あとから復習しやすい形にする。

---

## SSH接続

### 公開鍵認証でSSH接続する

```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```

意味。

```text
ssh
→ SSH接続する

-p 2222
→ 接続先ポートとして2222番を指定する

-i ~/.ssh/my_test_key
→ SSH接続に使う秘密鍵を指定する

toki@localhost
→ localhostにtokiユーザーとして接続する
```

NAT環境では、VirtualBoxのポートフォワーディングにより、Mac側の2222番ポートがUbuntu VM側の22番ポートへ転送される。

```text
Mac localhost:2222
    ↓
VirtualBox Port Forwarding
    ↓
Ubuntu VM :22
```

---

## 鍵ペア作成

### ED25519形式の鍵ペアを作成する

```bash
ssh-keygen -t ed25519 -f ~/.ssh/my_test_key
```

意味。

```text
ssh-keygen
→ SSH鍵を作成するコマンド

-t ed25519
→ 鍵の種類としてED25519を指定する

-f ~/.ssh/my_test_key
→ 作成する鍵ファイル名を指定する
```

作成されるファイル。

```text
~/.ssh/my_test_key      # 秘密鍵
~/.ssh/my_test_key.pub  # 公開鍵
```

注意点。

```text
秘密鍵 my_test_key は外部に公開しない。
サーバの authorized_keys に登録するのは公開鍵 my_test_key.pub。
```

---

## 公開鍵の転送

### scpで公開鍵をサーバへ転送する

```bash
scp -P 2222 -i ~/.ssh/id_rsa ~/.ssh/my_test_key.pub toki@localhost:~
```

意味。

```text
scp
→ SSHを使ってファイルを転送するコマンド

-P 2222
→ 転送先SSHポートとして2222番を指定する

-i ~/.ssh/id_rsa
→ scpでサーバにログインするための秘密鍵を指定する

~/.ssh/my_test_key.pub
→ 転送する公開鍵

toki@localhost:~
→ 接続先のtokiユーザーのホームディレクトリへ転送する
```

ポイント。

```text
ここで指定している -i ~/.ssh/id_rsa は、転送したい新しい鍵ではなく、すでにサーバへログインできる既存の秘密鍵。

新しい公開鍵 my_test_key.pub をサーバへ送るために、既存の秘密鍵 id_rsa でログインしている。
```

---

## authorized_keys への登録

### 公開鍵を authorized_keys に追記する

```bash
cat ~/my_test_key.pub >> ~/.ssh/authorized_keys
```

意味。

```text
cat ~/my_test_key.pub
→ 公開鍵ファイルの内容を表示する

>>
→ 既存ファイルの末尾に追記する

~/.ssh/authorized_keys
→ SSH公開鍵認証で使う公開鍵の登録先
```

注意点。

```text
> だと上書きになる。
>> は追記。

authorized_keys に既存の鍵がある場合は、基本的に >> を使う。
```

---

## .ssh 配下の権限確認

### .ssh ディレクトリの権限を確認する

```bash
ls -ld ~/.ssh
```

目安。

```text
~/.ssh → 700
```

### authorized_keys の権限を確認する

```bash
ls -l ~/.ssh/authorized_keys
```

目安。

```text
~/.ssh/authorized_keys → 600
```

### 権限を修正する

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

意味。

```text
chmod 700 ~/.ssh
→ 所有者だけが読み書き実行できる

chmod 600 ~/.ssh/authorized_keys
→ 所有者だけが読み書きできる
```

---

## scpによるファイル転送

### MacからUbuntuサーバのホームディレクトリへ転送する

```bash
scp -P 2222 -i ~/.ssh/my_test_key test.html toki@localhost:~
```

意味。

```text
scp
→ ファイル転送する

-P 2222
→ SSH接続先ポートとして2222番を指定する

-i ~/.ssh/my_test_key
→ 認証に使う秘密鍵を指定する

test.html
→ 転送するファイル

toki@localhost:~
→ 接続先のtokiユーザーのホームディレクトリへ転送する
```

注意点。

```text
ssh コマンドではポート指定に -p を使う。
scp コマンドではポート指定に -P を使う。

ssh: -p
scp: -P
```

---

## 権限エラーの再現

### /var/www/html/ へ直接転送する

```bash
scp -P 2222 -i ~/.ssh/my_test_key ~/test.html toki@localhost:/var/www/html/
```

発生したエラー。

```text
scp: /var/www/html/test.html: Permission denied
```

意味。

```text
SSH接続と鍵認証は成功している。

しかし、接続先の /var/www/html/ に tokiユーザーで書き込む権限がないため、ファイル転送に失敗した。
```

---

## 権限が必要な場所への配置

### 一度ホームディレクトリへ転送する

```bash
scp -P 2222 -i ~/.ssh/my_test_key ~/test.html toki@localhost:~
```

### SSHでサーバへ入る

```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```

### sudoで /var/www/html/ へ移動する

```bash
sudo mv ~/test.html /var/www/html/
```

意味。

```text
scpでの転送は一般ユーザー権限で行う。

権限が必要な配置作業だけ、サーバ側でsudoを使う。
```

---

## HTTP表示確認

### Nginx経由でファイルを確認する

```bash
curl http://localhost/test.html
```

想定結果。

```text
permission test
```

意味。

```text
/var/www/html/test.html に配置したファイルが、Nginx経由で表示できるかを確認する。
```

---

## SSHサービス確認

### SSHサービスの状態を確認する

```bash
sudo systemctl status ssh
```

見るポイント。

```text
active (running)
→ SSHサービスが起動している
```

---

## SSHポート確認

### Ubuntu側で22番ポートを確認する

```bash
ss -tulnp | grep ':22'
```

見るポイント。

```text
22番ポートで sshd が LISTEN しているか
```

必要に応じて、root権限でプロセス名まで確認する。

```bash
sudo ss -tulnp | grep ':22'
```

---

## ncによるポート確認

### Mac側から localhost:2222 に接続できるか確認する

```bash
nc -vz localhost 2222
```

意味。

```text
nc
→ ネットワーク接続を確認するコマンド

-v
→ 詳細表示

-z
→ データを送らず、ポートが開いているかだけ確認する

localhost 2222
→ localhostの2222番ポートへ接続確認する
```

成功例。

```text
Connection to localhost port 2222 succeeded!
```

意味。

```text
Mac側から localhost:2222 まで通信が届いている。

VirtualBoxのポートフォワーディング経由で、Ubuntu VM側の22番ポートまで届いている可能性が高い。
```

注意点。

```text
ncはポート到達を確認するだけ。
SSHログインや公開鍵認証までは確認しない。
```

---

## SSHログ確認

### SSHサービスのログを確認する

```bash
sudo journalctl -u ssh
```

### 直近30行だけ確認する

```bash
sudo journalctl -u ssh -n 30
```

### リアルタイムで確認する

```bash
sudo journalctl -u ssh -f
```

### auth.log を確認する

```bash
sudo tail -n 50 /var/log/auth.log
```

見るポイント。

```text
Accepted publickey
→ 公開鍵認証に成功

Invalid user
→ 存在しないユーザーで接続しようとした

Failed password
→ パスワード認証に失敗

Failed publickey
→ 公開鍵認証に失敗

Connection closed
→ 接続が閉じられた
```

---

## SSHデバッグ

### 詳細ログを出してSSH接続する

```bash
ssh -vvv -p 2222 -i ~/.ssh/my_test_key toki@localhost
```

意味。

```text
-vvv
→ SSH接続の詳細なデバッグ情報を表示する
```

使い所。

```text
通常のssh接続で原因が分からない時に使う。

どの設定ファイルを読んでいるか
どの鍵を使おうとしているか
サーバへ接続できているか
公開鍵認証が成功しているか
どこで止まっているか

を確認しやすい。
```

---

## 使い分けまとめ

```text
ssh
→ SSHログインする

scp
→ SSHを使ってファイル転送する

ssh-keygen
→ SSH鍵を作成する

chmod
→ .ssh や authorized_keys の権限を整える

systemctl status ssh
→ SSHサービスが起動しているか確認する

ss
→ Ubuntu側でポートがLISTENしているか確認する

nc
→ 接続元から指定ポートまで届くか確認する

journalctl -u ssh
→ SSH接続の成功・失敗ログを確認する

tail /var/log/auth.log
→ 認証ログを確認する

ssh -vvv
→ SSH接続の詳細なデバッグ情報を確認する
```

---

## 切り分けの順番

SSH接続できない場合は、以下の順番で確認する。

```text
1. SSHサービスは起動しているか
2. Ubuntu側で22番ポートがLISTENしているか
3. VirtualBoxのポートフォワーディングは正しいか
4. Mac側からlocalhost:2222へ届くか
5. SSHコマンドで -p 2222 を指定しているか
6. ユーザー名は正しいか
7. 秘密鍵の指定は正しいか
8. authorized_keys に公開鍵が登録されているか
9. .ssh と authorized_keys の権限は正しいか
10. journalctl -u ssh に何が出ているか
11. ssh -vvv でどこまで進んでいるか確認する
```

---

## 学び

SSH接続は、単にコマンドを実行するだけではなく、複数の要素が関係している。

```text
SSHサービスが起動しているか
ポートがLISTENしているか
ポートフォワーディングが正しいか
接続先IP・ポートが正しいか
ユーザー名が正しいか
鍵ファイルが正しいか
authorized_keys に公開鍵が登録されているか
.ssh 配下の権限が正しいか
ログに何が出ているか
```

これらを順番に確認することで、SSH接続できない時にどこで問題が起きているかを切り分けやすくなる。

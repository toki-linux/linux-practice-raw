# SSHログ確認

## 目的

SSH接続の成功・失敗を、サーバ側のログから確認する。

この検証では、公開鍵認証によるSSH接続を行い、接続成功時と接続失敗時にどのようなログが残るかを確認する。

---

## 環境

| 項目 | 内容 |
|---|---|
| 接続元 | Mac |
| 接続先 | Ubuntu Server |
| 仮想化環境 | VirtualBox |
| ネットワーク | NAT / ポートフォワーディング |
| 接続先ポート | ホスト側: 2222 → VM側: 22 |
| 認証方式 | 公開鍵認証 |
| 確認ログ | `journalctl -u ssh` |

---

## 前提

SSH接続のログは、サーバ側で確認する。

Ubuntuでは、以下のコマンドでSSHサービスに関するログを確認できる。

```bash
sudo journalctl -u ssh
```
環境によっては、以下のファイルにも認証ログが記録される。
```bash
sudo tail -n 50 /var/log/auth.log
```
## 手順
1. SSH接続を成功させる

接続元Macから、公開鍵認証でUbuntuサーバへSSH接続する。
```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```
接続できたら、サーバ側で以下を確認する。
```txt
whoami
hostname
pwd
```
2. SSH接続成功時のログを確認する

サーバ側でSSHログを確認する。
```bash
sudo journalctl -u ssh
```
直近のログだけ確認する場合。
```bash
sudo journalctl -u ssh -n 30
```
リアルタイムで確認する場合。
```bash
sudo journalctl -u ssh -f
```
確認したいポイント。
```txt
Accepted publickey
ユーザー名
接続元IP
sshd
```
ログ例。
```txt
sshd[1234]: Accepted publickey for toki from 10.0.2.2 port 54321 ssh2
sshd[1234]: pam_unix(sshd:session): session opened for user toki(uid=1000)
```
このログから、toki ユーザーとして公開鍵認証に成功したことが分かる。

3. SSH接続を失敗させる

接続元Macから、存在しない秘密鍵を指定して接続を試す。
```bash
ssh -p 2222 -i ~/.ssh/wrong_key toki@localhost
```
または、存在しないユーザーで接続を試す。
```bash
ssh -p 2222 -i ~/.ssh/my_test_key wronguser@localhost
```
4. SSH接続失敗時のログを確認する

サーバ側でログを確認する。
```bash
sudo journalctl -u ssh -n 50
```
確認したいポイント。
```txt
Failed publickey
Invalid user
Permission denied
接続元IP
ユーザー名
```
ログ例。
```txt
sshd[1235]: Invalid user wronguser from 10.0.2.2 port 54322
sshd[1235]: Failed publickey for invalid user wronguser from 10.0.2.2 port 54322 ssh2
```
このログから、存在しないユーザーでSSH接続しようとして失敗したことが分かる。
```txt
実際に確認したログ
SSH接続成功時のログ
May 06 12:11:15 ubuntu-toki sshd[14087]: Accepted publickey for toki from 10.0.2.2 port 49631 ssh2: ED25519 SHA256:...
May 06 12:11:15 ubuntu-toki sshd[14087]: pam_unix(sshd:session): session opened for user toki(uid=1000) by (uid=0)
```
このログから、toki ユーザーで公開鍵認証に成功し、SSHセッションが開かれたことが分かる。
```txt
Accepted publickey：公開鍵認証に成功
for toki：toki ユーザーでログイン
from 10.0.2.2：接続元IP
ssh2: ED25519：ED25519形式の鍵を使用
session opened：SSHセッション開始
SSH接続失敗時のログ
```
存在しないユーザー wronguser で接続を試した。
```txt
May 06 12:14:46 ubuntu-toki sshd[14164]: Invalid user wronguser from 10.0.2.2 port 49633
May 06 12:15:00 ubuntu-toki sshd[14164]: pam_unix(sshd:auth): check pass; user unknown
May 06 12:15:00 ubuntu-toki sshd[14164]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=10.0.2.2
May 06 12:15:02 ubuntu-toki sshd[14164]: Failed password for invalid user wronguser from 10.0.2.2 port 49633 ssh2
May 06 12:15:18 ubuntu-toki sshd[14164]: Connection closed by invalid user wronguser 10.0.2.2 port 49633 [preauth]
May 06 12:15:18 ubuntu-toki sshd[14164]: PAM 2 more authentication failures; logname= uid=0 euid=0 tty=ssh ruser= rhost=10.0.2.2
```
このログから、存在しない wronguser でSSH接続しようとして失敗したことが分かる。
```txt
Invalid user wronguser：存在しないユーザーで接続しようとした
user unknown：そのユーザーはシステム上に存在しない
Failed password for invalid user wronguser：存在しないユーザーに対するパスワード認証が失敗
Connection closed ... [preauth]：認証完了前に接続が閉じられた
PAM 2 more authentication failures：追加で認証失敗が発生した
```
## 結果

SSH接続に成功した場合、サーバ側のログに Accepted publickey が記録されることを確認した。

また、存在しないユーザーで接続しようとした場合、Invalid user や user unknown が記録されることを確認した。

今回の失敗ログでは Failed password が出ており、存在しないユーザーに対してパスワード認証が失敗していることが分かった。

## 確認できたこと
SSH接続の成功・失敗はサーバ側ログで確認できる
公開鍵認証に成功すると Accepted publickey が記録される
存在しないユーザーで接続すると Invalid user が記録される
認証に失敗すると Failed password や Failed publickey が記録される
ログを見ることで、接続元IP・ユーザー名・認証方式を確認できる
## 学び

SSH接続の成否は、接続元の画面だけでなく、サーバ側のログを見ることでより正確に判断できる。

成功時は Accepted publickey によって、公開鍵認証に成功したことが確認できる。

一方で、存在しないユーザーで接続した場合は Invalid user や user unknown が記録される。

今回の失敗ログでは Failed password が出ており、接続失敗の理由が「公開鍵そのものの失敗」ではなく、存在しないユーザーに対するパスワード認証失敗であることも読み取れた。

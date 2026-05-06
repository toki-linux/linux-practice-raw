## 実際に確認したログ

### SSH接続成功時のログ

```text
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
## 学び

SSH接続の成否は、接続元の画面だけでなく、サーバ側のログを見ることでより正確に判断できる。

成功時は `Accepted publickey` によって、公開鍵認証に成功したことが確認できる。

一方で、存在しないユーザーで接続した場合は `Invalid user` や `user unknown` が記録される。

今回の失敗ログでは `Failed password` が出ており、接続失敗の理由が「公開鍵そのものの失敗」ではなく、存在しないユーザーに対するパスワード認証失敗であることも読み取れた。

このように、ログを見ることで、ユーザー名の誤り・認証方式・接続元IP・認証失敗の段階を切り分けやすくなる。

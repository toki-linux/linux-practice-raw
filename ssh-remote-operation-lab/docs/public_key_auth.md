# SSH公開鍵認証

## 目的

パスワード認証ではなく、公開鍵認証を使って接続元PCからUbuntuサーバへSSH接続できることを確認する。

この検証では、接続元PCで作成した公開鍵を接続先Ubuntuの `authorized_keys` に登録し、秘密鍵を使ってSSH接続できることを確認する。

---

## 環境

| 項目 | 内容 |
|---|---|
| 接続元 |  Mac |
| 接続先 | Ubuntu Server |
| 仮想化環境 | VirtualBox |
| ネットワーク | NAT / ポートフォワーディング |
| 接続先ポート | ホスト側: 2222 → VM側: 22 |
| 認証方式 | 公開鍵認証 |


---

## 公開鍵認証の流れ

公開鍵認証では、接続元PCに秘密鍵と公開鍵を作成し、公開鍵を接続先サーバに登録する。

```text
接続元PC
├── 秘密鍵
└── 公開鍵
      ↓ 登録
接続先Ubuntu
└── ~/.ssh/authorized_keys
```

## 手順

1. 接続元PCで鍵ペアを作成する

接続元PCで、検証用の鍵ペアを作成する。

```bash
ssh-keygen -t ed25519 -f ~/.ssh/my_test_key
```
作成されるファイルは以下。
```txt
~/.ssh/my_test_key      # 秘密鍵
~/.ssh/my_test_key.pub  # 公開鍵
```
`my_test_key` は秘密鍵なので、外部に公開したりサーバへ送ったりしない。

サーバ側の`authorized_keys` に登録するのは、公開鍵である` my_test_key.pub。`

2. 公開鍵をサーバへ転送する

すでに接続できる既存の秘密鍵を使って、作成した公開鍵をサーバへ転送する。
```bash
scp -P 2222 -i ~/.ssh/id_rsa ~/.ssh/my_test_key.pub toki@localhost:~
```
ここで指定している` -i ~/.ssh/id_rsa` は、今回登録したい新しい鍵ではなく、すでにサーバへログインできる既存の秘密鍵。

`scp `はファイル転送を行うコマンドだが、内部ではSSH接続を使っている。
そのため、ファイルを送る時にもサーバへログインするための認証が必要になる。

今回の場合、すでにサーバ側の` authorized_keys `に登録されている公開鍵と対応する秘密鍵が `~/.ssh/id_rsa `だったため、それを使ってログインしている。

3. サーバ側で公開鍵を `authorized_keys` に登録する

別の鍵、またはパスワード認証でサーバ側の toki ユーザーにログインする。
```bash
ssh -p 2222 -i ~/.ssh/id_rsa toki@localhost
```
ホームディレクトリに、先ほど転送した公開鍵が届いているか確認する。
```bash
ls -l ~/my_test_key.pub
```
届いていたら、その公開鍵を `authorized_keys `に追記する。
```bash
cat ~/my_test_key.pub >> ~/.ssh/authorized_keys
```
4.` .ssh `ディレクトリと `authorized_keys `の権限を確認する

サーバ側で、.ssh ディレクトリと `authorized_keys` の権限を確認する。
```bash
ls -ld ~/.ssh
ls -l ~/.ssh/authorized_keys
```
目安は以下。
```txt
~/.ssh              → 700
~/.ssh/authorized_keys → 600
```
必要に応じて、以下のように修正する。
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```
5. 新しく作成した秘密鍵でSSH接続する

一度` exit `で接続を終了する。
```bash
exit
```
接続元PCから、新しく作成した秘密鍵を使ってSSH接続する。
```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```
接続できれば、新しく作成した鍵ペアによる公開鍵認証は成功。

6. 接続確認

接続後、以下のコマンドで接続先を確認する。
```bash
whoami
pwd
hostname
```
確認する内容。
```txt
whoami   → toki
pwd      → /home/toki
hostname → 接続先Ubuntuのホスト名
```
## 学び
`scp `はファイル転送コマンドだが、内部ではSSH接続を使っている。

そのため、`scp `でファイルを送る時にも、接続先サーバへログインするための認証が必要になる。

今回の検証では、新しく作成した公開鍵` my_test_key.pub `をサーバへ送るために、すでに接続可能な既存の秘密鍵` ~/.ssh/id_rsa `を使用した。

ここで使う` -i ~/.ssh/id_rsa` は、転送したい鍵ではなく、サーバへログインするための秘密鍵である。

また、サーバ側の` authorized_keys `に登録するのは公開鍵であり、秘密鍵は接続元PCに保管する。
```txt
接続元PC
├── my_test_key      # 秘密鍵。自分だけが持つ
└── my_test_key.pub  # 公開鍵。サーバへ登録する

接続先サーバ
└── ~/.ssh/authorized_keys  # 公開鍵を登録する場所
```
公開鍵認証では、接続元PCの秘密鍵と、接続先サーバの` authorized_keys `に登録された公開鍵の組み合わせによって認証される。


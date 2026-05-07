# ssh-remote-operation-lab

## 概要

SSHを使ったリモートサーバ接続、公開鍵認証、ファイル転送、権限エラーの再現と解決、SSHログ確認を行った実践記録です。

このリポジトリでは、単にSSHで接続するだけではなく、接続・転送・権限・ログ確認・原因切り分けまでを一連の流れとして整理しています。

主に以下を扱っています。

- SSHによるリモート接続
- 公開鍵認証
- scpによるファイル転送
- 転送時の権限エラー
- SSHログ確認
- NAT環境でのポートフォワーディング
- SSH接続できない時の切り分け

---

## 目的

このリポジトリの目的は、SSHを使った基本的なリモート操作と、接続トラブル時の切り分け方法を理解することです。

特に、以下を重視しています。

- SSHでリモート環境へ接続できる
- 公開鍵認証の流れを理解する
- `scp` でファイル転送できる
- 権限が必要な場所へ直接転送できない理由を理解する
- SSH接続の成功・失敗をログから確認できる
- NAT環境下でのポートフォワーディングの考え方を整理する

---

## 検証環境

| 項目 | 内容 |
|---|---|
| 接続元 | Mac / Windows |
| 接続先 | Ubuntu Server |
| 仮想化環境 | VirtualBox |
| ネットワーク | NAT / ポートフォワーディング |
| SSHポート | VM側: 22 / ホスト側: 2222 |
| 認証方式 | 公開鍵認証 |

---

## 構成イメージ

```text
接続元PC
Mac / Windows
    ↓ SSH
localhost:2222
    ↓ VirtualBox Port Forwarding
Ubuntu VM :22
    ↓
sshd
```

NAT環境では、VMが外部から直接見えないため、VirtualBoxのポートフォワーディングを使って接続します。

```text
ホストPCの2222番ポート
    ↓
Ubuntu VMの22番ポート
```

接続例：

```bash
ssh -p 2222 toki@localhost
```

---

## 学習・検証内容

### 1. SSH公開鍵認証

公開鍵認証を使って、接続元PCからUbuntuサーバへSSH接続できることを確認しました。

記録した内容は以下です。

- 鍵の作成
- 公開鍵の配置
- `authorized_keys` の確認
- `known_hosts` に登録される流れ
- `.ssh` ディレクトリと鍵ファイルの権限
- SSH接続コマンド

詳細：

- [SSH公開鍵認証](docs/public_key_auth.md)

---

### 2. scpによるファイル転送

`scp` を使って、接続元PCからUbuntuサーバへファイルを転送しました。

記録した内容は以下です。

- 転送元
- 転送先
- 使用したコマンド
- 転送後の確認
- 転送に失敗した場合の原因

詳細：

- [scpによるファイル転送](docs/scp_file_transfer.md)

---

### 3. 権限エラーの再現と解決

一般ユーザーで、権限が必要なディレクトリへ直接ファイル転送しようとして失敗するケースを再現しました。

例：

```bash
scp index.html toki@server:/var/www/html/
```

一般ユーザーには `/var/www/html/` への書き込み権限がないため、直接転送は失敗します。

解決方法として、一度ユーザーのホームディレクトリへ転送してから、サーバ側で `sudo mv` を使って配置しました。

```bash
scp index.html toki@server:/home/toki/
sudo mv /home/toki/index.html /var/www/html/
```

詳細：

- [権限エラーの再現と解決](docs/permission_error.md)

---

### 4. SSHログ確認

SSH接続の成功・失敗をログから確認しました。

使用するコマンド例：

```bash
sudo journalctl -u ssh
```

または、

```bash
sudo tail -n 50 /var/log/auth.log
```

記録した内容は以下です。

- SSH接続成功時のログ
- SSH接続失敗時のログ
- 接続元IP
- 接続ユーザー
- 認証方式

詳細：

- [SSHログ確認](docs/ssh_logs.md)

---

### 5. NAT環境とポートフォワーディング

VirtualBoxのNAT環境では、VMへ直接SSH接続できないため、ポートフォワーディングを設定して接続しました。

記録した内容は以下です。

- NAT環境で直接接続できない理由
- ホスト側ポートとゲスト側ポートの対応
- VirtualBoxの設定内容
- 実際のSSH接続コマンド
- 接続できない時の切り分け

詳細：

- [NAT環境とポートフォワーディング](docs/nat_port_forwarding.md)

---

## ディレクトリ構成

```text
ssh-remote-operation-lab/
├── README.md
├── docs/
│   ├── public_key_auth.md
│   ├── scp_file_transfer.md
│   ├── permission_error.md
│   ├── ssh_logs.md
│   └── nat_port_forwarding.md
└── notes/
    └── commands.md
```

---

## 主なドキュメント

- [SSH公開鍵認証](docs/public_key_auth.md)
- [scpによるファイル転送](docs/scp_file_transfer.md)
- [scp転送時の権限エラー](docs/permission_error.md)
- [SSHログ確認](docs/ssh_logs.md)
- [NAT環境とポートフォワーディング](docs/nat_port_forwarding.md)
- [コマンドメモ](notes/commands.md)

---

## 使用コマンド

この検証で使用した主なコマンドです。

```text
ssh
scp
ssh-keygen
ssh-copy-id
chmod
chown
systemctl
journalctl
ss
nc
tail
grep
```

---

## 切り分けの考え方

SSH接続できない場合、以下の順番で確認します。

```text
1. SSHサービスは起動しているか
   ↓
2. 22番ポートでLISTENしているか
   ↓
3. ポートフォワーディングは正しいか
   ↓
4. 接続先IP・ポートは正しいか
   ↓
5. ユーザー名は正しいか
   ↓
6. 鍵ファイル・権限は正しいか
   ↓
7. SSHログに何が出ているか
```

確認コマンド例：

```bash
sudo systemctl status ssh
ss -tulnp | grep ':22'
nc -vz localhost 2222
ssh -vvv -p 2222 toki@localhost
sudo journalctl -u ssh
```

---

## 学び

この検証を通じて、SSH接続は単にコマンドを実行するだけではなく、以下の複数の要素が関係していることを整理しました。

- SSHサービスが起動していること
- 接続先ポートが開いていること
- NAT環境ではポートフォワーディングが必要になること
- 公開鍵と秘密鍵の対応が正しいこと
- `.ssh` 配下の権限が適切であること
- 接続できない場合はログから原因を確認すること

また、`scp` によるファイル転送では、転送先の権限が接続ユーザーに依存するため、権限が必要な場所へは一度ホームディレクトリに転送してから `sudo` で移動する流れを確認しました。

SSH接続・ファイル転送・権限・ログ確認を分けて整理することで、リモート操作で問題が起きた時に、どこで詰まっているのかを段階的に切り分ける考え方を学びました。

---

## 今後の改善案

- パスワード認証と公開鍵認証の違いを比較する
- SSH接続失敗パターンを複数作る
- `Permission denied (publickey)` の原因を整理する
- `known_hosts` の警告を再現して解決する
- `sshd_config` の設定変更を検証する
- ファイル転送後にNginxで表示確認する

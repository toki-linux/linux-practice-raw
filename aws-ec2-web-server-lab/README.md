```txt
aws-ec2-web-server-lab/
├── README.md
├── docs/
│   ├── ec2_setup.md
│   ├── ssh_connection.md
│   ├── security_group.md
│   ├── nginx_setup.md
│   └── troubleshooting.md
└── notes/
    └── commands.md
```


今の所のREADME.md
# aws-ec2-web-server-lab

## 概要

AWS EC2上にUbuntu Serverを作成し、SSH接続・Nginxインストール・セキュリティグループ設定・Webページ表示確認を行う実践記録です。

これまでVirtualBox上で行ってきたLinuxサーバ操作を、AWS上のクラウドサーバで再現することを目的としています。

---

## 目的

このリポジトリでは、AWS EC2を使ってクラウド上にWebサーバを構築し、以下の流れを実践する。

- EC2インスタンスを作成する
- SSHでEC2へ接続する
- Ubuntu上にNginxをインストールする
- セキュリティグループで22番・80番ポートを制御する
- ブラウザからNginxの初期ページを表示する
- `systemctl` / `ss` / `curl` / ログを使って状態確認する
- 接続できない場合の切り分けを行う

---

## 今回のゴール

```text
EC2上にUbuntu Serverを作成する
  ↓
SSHで接続する
  ↓
Nginxをインストールする
  ↓
セキュリティグループで80番を許可する
  ↓
ブラウザで http://<EC2_PUBLIC_IP> にアクセスする
  ↓
Nginxの初期ページを表示する
```

---

## 構成イメージ

```text
Mac
  ↓ SSH / HTTP
AWS EC2
  ↓
Ubuntu Server
  ↓
Nginx :80
```

SSH接続時のイメージ。

```text
Mac
  ↓ ssh -i <KEY_FILE> ubuntu@<EC2_PUBLIC_IP>
EC2 Ubuntu Server
```

Web表示時のイメージ。

```text
Browser
  ↓ http://<EC2_PUBLIC_IP>
EC2 Ubuntu Server
  ↓
Nginx :80
```

---

## VirtualBox環境との対応

| VirtualBoxでの学習 | AWS EC2での学習 |
|---|---|
| VirtualBox上のUbuntu VM | AWS上のEC2インスタンス |
| `localhost:2222` へのSSH接続 | `<EC2_PUBLIC_IP>` へのSSH接続 |
| VirtualBoxのポートフォワーディング | AWSのセキュリティグループ |
| Ubuntu内のNginx | EC2内のNginx |
| `curl http://localhost` | `curl http://<EC2_PUBLIC_IP>` |
| VMを停止・削除 | EC2を停止・終了 |

---

## 学習で意識すること

この検証では、単にEC2を作るだけではなく、以下を意識する。

- 自分のPCの外にあるLinuxサーバへSSH接続する
- AWS側の通信制御であるセキュリティグループを理解する
- Linux側のサービス状態とAWS側の許可設定を分けて確認する
- Webページが表示されない場合に、どの層で止まっているかを切り分ける
- 作業後はEC2を停止または終了し、料金事故を防ぐ

---

## 使用する主な技術・サービス

| 種類 | 内容 |
|---|---|
| クラウド | AWS |
| サーバ | EC2 |
| OS | Ubuntu Server |
| Webサーバ | Nginx |
| 接続方式 | SSH |
| 認証 | キーペア認証 |
| 通信制御 | セキュリティグループ |
| 確認コマンド | `ssh`, `systemctl`, `ss`, `curl`, `journalctl` |

---

## ディレクトリ構成

```text
aws-ec2-web-server-lab/
├── README.md
├── docs/
│   ├── ec2_setup.md
│   ├── ssh_connection.md
│   ├── security_group.md
│   ├── nginx_setup.md
│   └── troubleshooting.md
└── notes/
    └── commands.md
```

---

## ドキュメント一覧

| ファイル | 内容 |
|---|---|
| [ec2_setup.md](docs/ec2_setup.md) | EC2インスタンス作成手順 |
| [ssh_connection.md](docs/ssh_connection.md) | MacからEC2へSSH接続する手順 |
| [security_group.md](docs/security_group.md) | 22番・80番ポートの許可設定 |
| [nginx_setup.md](docs/nginx_setup.md) | Nginxのインストールと表示確認 |
| [troubleshooting.md](docs/troubleshooting.md) | 接続できない・表示できない場合の切り分け |
| [commands.md](notes/commands.md) | 使用したコマンドまとめ |

---

## 作業前の注意

AWSは従量課金のサービスであり、使った分だけ料金が発生する可能性がある。

そのため、作業前に以下を確認する。

- AWS Budgetsで予算アラートを設定する
- EC2は必要な時だけ起動する
- 作業後はEC2を停止または終了する
- 使わないElastic IPやEBSボリュームを残さない
- 秘密鍵 `.pem` をGitHubにアップロードしない
- 実際のIPアドレスやAWSアカウントIDはGitHubに載せない

---

## GitHubに載せない情報

以下の情報はGitHubに載せない。

```text
秘密鍵 .pem
AWSアクセスキー
AWSシークレットアクセスキー
AWSアカウントID
実際のパブリックIP
自分のグローバルIP
インスタンスID
セキュリティグループID
請求画面のスクリーンショット
```

GitHub上では、以下のように伏せ字にする。

```text
<EC2_PUBLIC_IP>
<KEY_FILE>
<MY_GLOBAL_IP>
<INSTANCE_ID>
<SECURITY_GROUP_ID>
```

---

## 想定する確認コマンド

SSH接続。

```bash
ssh -i ~/.ssh/<KEY_FILE>.pem ubuntu@<EC2_PUBLIC_IP>
```

接続先確認。

```bash
whoami
hostname
pwd
```

Nginx状態確認。

```bash
sudo systemctl status nginx
```

80番ポート確認。

```bash
ss -tulnp | grep ':80'
```

EC2内からHTTP確認。

```bash
curl http://localhost
```

ブラウザから確認。

```text
http://<EC2_PUBLIC_IP>
```

---

## 切り分けで意識すること

Webページが表示されない場合は、以下の順番で確認する。

```text
1. EC2が起動しているか
2. パブリックIPが正しいか
3. セキュリティグループで80番が許可されているか
4. EC2内でNginxが起動しているか
5. EC2内で80番ポートがLISTENしているか
6. EC2内から curl http://localhost が成功するか
7. Nginxのログにエラーが出ていないか
```

SSH接続できない場合は、以下を確認する。

```text
1. EC2が起動しているか
2. パブリックIPが正しいか
3. セキュリティグループで22番が許可されているか
4. 接続元IPが許可されているか
5. 秘密鍵ファイルを指定しているか
6. 秘密鍵の権限が正しいか
7. ユーザー名が正しいか
```

---

## 学びとして残したいこと

この検証を通じて、以下を整理する。

- EC2はAWS上で作成するLinuxサーバである
- EC2でもLinuxの基本コマンドやNginx操作は同じように使える
- VirtualBoxのポートフォワーディングに近い役割を、AWSではセキュリティグループが持つ
- Linux側でNginxが起動していても、AWS側で80番が許可されていなければ外からアクセスできない
- SSH接続では、パブリックIP・秘密鍵・ユーザー名・セキュリティグループを分けて確認する必要がある
- AWS学習では、作業記録をGitHubに残し、不要になった環境は終了することが重要

---

## 今後追加する予定

- EC2作成手順
- SSH接続手順
- セキュリティグループ設定
- Nginxインストール手順
- Web表示確認ログ
- 接続できない場合の切り分け
- AWS料金事故を防ぐチェックリスト

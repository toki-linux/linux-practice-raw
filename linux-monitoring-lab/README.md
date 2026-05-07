
# linux-monitoring-lab

## 概要

Nginxとsystemdで管理しているPythonアプリを対象に、サービス状態・ポート状態・HTTP応答を確認する監視スクリプトを作成し、異常検知・ログ記録・自動復旧を検証した実践記録です。

このリポジトリでは、単にサービスが起動しているかだけでなく、Webサービスとして正常に応答しているかを複数の観点から確認しています。

主に以下を確認しました。

- `nginx.service` が起動しているか
- `myapp.service` が起動しているか
- 80番ポートがLISTENしているか
- 3000番ポートがLISTENしているか
- Nginx経由でHTTP応答が返るか
- 異常時にログへ記録できるか
- `myapp.service` 停止時に自動復旧できるか

---

## 目的

このリポジトリの目的は、Webサービス運用時に必要となる基本的な監視・ログ確認・自動復旧の流れを実践することです。

特に、以下を重視しています。

- サービス状態だけで正常・異常を判断しない
- ポート状態とHTTP応答も分けて確認する
- 異常時の状態をログに残す
- cronを使って監視スクリプトを定期実行する
- 停止したサービスを自動復旧できることを確認する

---

## 構成イメージ

```text
Client / curl
    ↓
Nginx :80
    ↓ /app/ をリバースプロキシ
Python App :3000
    ↓
systemd myapp.service

cron
    ↓
check_web_stack.sh
    ↓
/var/log/web_stack_check.log
```

---

## 監視項目

このスクリプトでは、以下を確認します。

| 項目 | 確認内容 |
|---|---|
| nginx | `nginx.service` が active か |
| myapp | `myapp.service` が active か |
| port 80 | Nginxが80番ポートでLISTENしているか |
| port 3000 | Pythonアプリが3000番ポートでLISTENしているか |
| HTTP応答 | `curl http://localhost/app/` が成功するか |

---

## 主な機能

- サービス状態の確認
- ポート状態の確認
- HTTP応答確認
- ログ出力
- `myapp.service` 停止時の自動復旧
- cronによる定期実行

---

## 使用技術・コマンド

| 種類 | 内容 |
|---|---|
| OS | Ubuntu |
| Webサーバ | Nginx |
| upstream | Python `http.server` |
| サービス管理 | systemd |
| 定期実行 | cron |
| スクリプト | Bash |
| 確認コマンド | `systemctl`, `ss`, `grep`, `curl` |
| ログ出力先 | `/var/log/web_stack_check.log` |

---

## ディレクトリ構成

```text
linux-monitoring-lab/
├── README.md
├── scripts/
│   └── check_web_stack.sh
├── configs/
│   ├── myapp.service
│   └── nginx-default.conf
├── logs/
│   ├── normal.log
│   ├── myapp_down.log
│   └── auto_recovery.log
└── docs/
    ├── auto_recovery_test.md
    ├── permission_denied_tmp.md
    └── monitoring_notes.md
```

---

## 主なファイル

- [監視・自動復旧スクリプト](https://github.com/toki-linux/linux-practice-raw/tree/main/linux-monitoring-lab/scripts)
- [myapp.service](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/configs/myapp.service)
- [Nginx設定ファイル](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/configs/nginx-default.conf)

---

## 検証ログ

- [正常時ログ](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/logs/normal.log)
- [myapp停止ログ](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/logs/myapp_down.log)
- [自動復旧時ログ](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/logs/auto_recovery.log)

---

## 詳細ドキュメント

- [自動復旧テスト](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/docs/auto_recovery_test.md)
- [/tmpログファイルのPermission denied](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/docs/permission_denied_tmp.md)
- [監視スクリプトの学び](https://github.com/toki-linux/linux-practice-raw/blob/main/linux-monitoring-lab/docs/monitoring_notes.md)

---

## 検証結果

### 正常時

すべての監視項目がOKになることを確認しました。

```text
nginx: OK
myapp: OK
port 80: OK
port 3000: OK
http check: OK
```

この結果から、Nginx、Pythonアプリ、ポート状態、HTTP応答がすべて正常であることを確認できました。

---

### myapp停止時

`myapp.service` を手動で停止し、監視スクリプトが異常を検知できることを確認しました。

```text
nginx: OK
myapp: NG
port 80: OK
port 3000: NG
http check: NG
```

この結果から、Nginx自体は起動しているが、`myapp.service` が停止しており、3000番ポートで待ち受けるプロセスが存在しないことが分かりました。

また、HTTP応答確認もNGになっているため、Nginx経由でもアプリケーションへ正常に到達できない状態だと判断できます。

---

### 自動復旧時

rootのcronからスクリプトを実行し、`myapp.service` が停止していた場合に自動起動できることを確認しました。

```text
nginx: OK
myapp: NG
action: starting myapp
myapp restart: OK
port 80: OK
port 3000: OK
http check: OK
```

この結果から、`myapp.service` の停止を検知した後、`systemctl start myapp` によって自動復旧できたことが分かりました。

---

## 実施手順

最初に、手動でサービス状態・ポート状態・HTTP応答を確認しました。

```text
systemctl status nginx
systemctl status myapp
ss -tulnp
curl http://localhost/app/
```

その後、確認手順をBashスクリプト化し、cronで定期実行する構成にしました。

さらに、`myapp.service` を意図的に停止させた状態で、異常検知と自動復旧ができることを確認しました。

---

## 発生したトラブル

### /tmpログファイルへのPermission denied

検証中、root権限で実行しているにもかかわらず、`/tmp/web_stack_check.log` へ書き込めない問題が発生しました。

そのため、ログ出力先を以下のように変更しました。

```text
変更前:
/tmp/web_stack_check.log

変更後:
/var/log/web_stack_check.log
```

詳細は以下に記録しています。

- [/tmpログファイルのPermission denied](docs/permission_denied_tmp.md)

---

### 自動復旧直後のポート確認

`myapp.service` を自動起動した直後、`systemctl is-active myapp` では active になっていたが、直後のポート確認では `port 3000: NG` になることがありました。

後から手動で確認すると3000番ポートはLISTENしていたため、サービス起動直後にポートが開くまでのわずかな時間差が原因だと考えました。

そのため、`systemctl start myapp` の直後に `sleep 2` を入れ、起動後に少し待ってからポート確認へ進むように修正しました。

詳細は以下に記録しています。

- [監視スクリプトの学び](docs/monitoring_notes.md)

---

## 学び

サービスが `active` でも、Webサービスとして正常に応答しているとは限らない。

そのため、サービス状態・ポート状態・HTTP応答を分けて確認することで、どの層で問題が起きているかを判断しやすくなると学びました。

また、cronを使うことで監視スクリプトを定期実行でき、root権限で実行することで停止したサービスの自動復旧もできることを確認しました。

今回の検証を通じて、障害発生後に調査するだけでなく、異常を検知し、ログに記録し、必要に応じて復旧する運用の流れを体験できました。

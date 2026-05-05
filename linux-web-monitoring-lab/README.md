この成果物の入口。何を作ったか、何ができるかを書く
# Linux Webサービス監視・自動復旧スクリプト

## 概要

Nginxとsystemdで管理しているPythonアプリを対象に、サービス状態・ポート状態・HTTP応答を確認する監視スクリプトを作成した。

また、`myapp.service` が停止していた場合に、root権限のcronから自動復旧できることを検証した。

## 目的

Webサービスが正常に動いているかを、以下の観点で確認する。

- サービスが起動しているか
- 必要なポートでLISTENしているか
- Nginx経由でHTTP応答が返るか
- 異常時にログへ記録できるか
- 停止したサービスを自動復旧できるか

## 構成

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

## 監視項目

このスクリプトでは、以下を確認する。

- `nginx.service` が active か
- `myapp.service` が active か
- 80番ポートがLISTENしているか
- 3000番ポートがLISTENしているか
- `curl http://localhost/app/` が成功するか

## 主な機能

- サービス状態の確認
- ポート状態の確認
- HTTP応答確認
- ログ出力
- myapp停止時の自動復旧
- cronによる定期実行

## 使用技術・コマンド

- Ubuntu
- Nginx
- Python http.server
- systemd
- cron
- Bash
- systemctl
- ss
- grep
- curl

## ディレクトリ構成

```text
linux-web-monitoring-lab/
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

## 検証結果

### 正常時

すべての監視項目がOKになることを確認した。

```text
nginx: OK
myapp: OK
port 80: OK
port 3000: OK
http check: OK
```

### myapp停止時

`myapp.service` を手動で停止し、監視スクリプトが異常を検知できることを確認した。

```text
myapp: NG
port 3000: NG
http check: NG
```

### 自動復旧時

root権限のcronからスクリプトを実行し、`myapp.service` が停止していた場合に自動起動できることを確認した。

```text
myapp: NG
action: starting myapp
myapp restart: OK
port 3000: OK
http check: OK
```

## 詳細ドキュメント

- [自動復旧テスト](docs/auto_recovery_test.md)
- [/tmpログファイルのPermission denied](docs/permission_denied_tmp.md)
- [監視スクリプトの学び](docs/monitoring_notes.md)

## 学び

サービスが `active` でも、Webサービスとして正常に応答しているとは限らない。

そのため、サービス状態・ポート状態・HTTP応答を分けて確認することで、どの層で問題が起きているかを判断しやすくなると学んだ。

また、cronを使うことで監視スクリプトを定期実行でき、root権限で実行することで停止したサービスの自動復旧もできることを確認した。

# configs

このフォルダには、linux-monitoring-lab で使用した設定ファイルを置いています。

NginxからPythonアプリへリバースプロキシする構成と、Pythonアプリをsystemdサービスとして管理するための設定をまとめています。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [myapp.service](myapp.service) | Pythonアプリをsystemdサービスとして起動するための設定ファイル |
| [nginx-default.conf](nginx-default.conf) | Nginxで `/app/` へのアクセスをPythonアプリへ転送する設定ファイル |

---

## myapp.service

`myapp.service` は、Python `http.server` をsystemdサービスとして起動するための設定です。

この設定により、Pythonアプリを以下のように管理できます。

```bash
sudo systemctl start myapp
sudo systemctl stop myapp
sudo systemctl status myapp

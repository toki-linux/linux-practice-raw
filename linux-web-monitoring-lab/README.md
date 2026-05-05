この成果物の入口。何を作ったか、何ができるかを書く
# Linux Webサービス監視・自動復旧スクリプト

## 概要

Nginxとsystemdで管理しているPythonアプリを対象に、サービス状態・ポート状態・HTTP応答を確認する監視スクリプトを作成した。

また、`myapp.service` が停止していた場合に、rootのcronから自動復旧できることを検証した。

## 目的

Webサービスが正常に動いているかを、以下の観点で確認する。

- サービスが起動しているか
- 必要なポートでLISTENしているか
- Nginx経由でHTTP応答が返るか
- 異常時にログへ記録できるか
- 停止したサービスを自動復旧できるか

## 構成

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
監視項目  

このスクリプトでは、以下を確認する。  

nginx.service が active か  
myapp.service が active か  
80番ポートがLISTENしているか  
3000番ポートがLISTENしているか  
curl http://localhost/app/ が成功するか  
主な機能  
サービス状態の確認  
ポート状態の確認  
HTTP応答確認  
ログ出力  
myapp停止時の自動復旧  
cronによる定期実行  
使用技術・コマンド  
Ubuntu  
Nginx  
Python http.server  
systemd  
cron  
Bash  
systemctl  
ss  
grep  
curl  
ディレクトリ構成  
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
検証結果  
正常時  
  
すべての監視項目がOKになることを確認した。  
  
nginx: OK  
myapp: OK  
port 80: OK  
port 3000: OK  
http check: OK  
myapp停止時  
  
myapp.service を手動で停止し、監視スクリプトが異常を検知できることを確認した。  
  
nginx: OK  
myapp: NG  
port 80: OK  
port 3000: NG  
http check: NG  
  
この結果から、Nginx自体は起動しているが、myapp.service が停止しており、3000番ポートで待ち受けるプロセスが存在しないことが分かる。  

自動復旧時  
  
rootのcronからスクリプトを実行し、myapp.service が停止していた場合に自動起動できることを確認した。  
  
nginx: OK  
myapp: NG  
action: starting myapp  
myapp restart: OK  
port 80: OK  
port 3000: OK  
http check: OK  
  
この結果から、myapp.service の停止を検知した後、systemctl start myapp によって自動復旧できたことが分かる。  
  
実施手順  
  
最初に、手動でサービス状態・ポート状態・HTTP応答を確認した。  
  
その後、確認手順をBashスクリプト化し、cronで定期実行する構成にした。  
  
さらに、myapp.service を意図的に停止させた状態で、異常検知と自動復旧ができることを確認した。  
  
発生したトラブル  
  
検証中、root権限で実行しているにもかかわらず /tmp/web_stack_check.log へ書き込めない問題が発生した。  
  
そのため、ログ出力先を /tmp/web_stack_check.log から /var/log/web_stack_check.log に変更した。  
  
詳細は以下に記録している。  
  
/tmpログファイルのPermission denied  
詳細ドキュメント  
自動復旧テスト  
/tmpログファイルのPermission denied  
監視スクリプトの学び  
自動復旧直後のポート確認  
myapp.service を自動起動した直後、`systemctl is-active myapp` では active になっていたが、直後のポート確認では `port 3000: NG` になることがあった。  
後から手動で確認すると3000番ポートはLISTENしていたため、サービス起動直後にポートが開くまでのわずかな時間差が原因だと考えた。  
そのため、`systemctl start myapp` の直後に `sleep 2` を入れ、起動後に少し待ってからポート確認へ進むように修正した。  
詳細は以下に記録している。  
- [監視スクリプトの学び](docs/monitoring_notes.md2)  

学び  

サービスが active でも、Webサービスとして正常に応答しているとは限らない。  
そのため、サービス状態・ポート状態・HTTP応答を分けて確認することで、どの層で問題が起きているかを判断しやすくなると学んだ。  
また、cronを使うことで監視スクリプトを定期実行でき、root権限で実行することで停止したサービスの自動復旧もできることを確認した。 
今回の検証を通じて、障害発生後に調査するだけでなく、異常を検知し、ログに記録し、復旧する運用の流れを体験できた。  

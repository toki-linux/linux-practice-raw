# 自動復旧テスト

## 目的

myapp.service が停止した場合に、監視スクリプトが異常を検知し、自動で復旧できるかを確認する。

## 手順

1. myapp.service を停止する

```bash
sudo systemctl stop myapp
cronまたは手動で監視スクリプトを実行する
sudo bash /home/toki/linux-monitoring-lab/check_web_stack.sh
ログを確認する
sudo tail -n 30 /var/log/web_stack_check.log
結果

myapp.service が停止していることを検知し、systemctl start myapp によって自動復旧できた。

学び

サービス状態、ポート状態、HTTP応答を分けて確認することで、どこに異常があるかを判断しやすくなる。

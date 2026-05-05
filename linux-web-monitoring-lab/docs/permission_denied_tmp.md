# /tmpログファイルのPermission denied

## 症状

root権限で監視スクリプトを実行したところ、`/tmp/web_stack_check.log` への書き込みで Permission denied が発生した。

## 原因

`toki` ユーザーで作成された `/tmp/web_stack_check.log` に対して、root権限のスクリプトから追記しようとしたため、/tmpの保護設定により拒否された可能性がある。

## 解決

ログ出力先を `/var/log/web_stack_check.log` に変更した。

LOG="/var/log/web_stack_check.log"
学び

root権限で実行していても、共有ディレクトリである /tmp 内のファイルでは権限や保護設定に注意が必要。
root権限のcronで実行する監視スクリプトのログは /var/log に置く方が自然。

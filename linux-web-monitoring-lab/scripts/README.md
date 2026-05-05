## 監視スクリプト

`scripts/check_web_stack.sh` では、Webサービスが正常に動いているかを以下の順番で確認しています。

1. `nginx.service` が active か確認
2. `myapp.service` が active か確認
3. `myapp.service` が停止していた場合は `systemctl start myapp` で自動起動
4. 80番ポートが LISTEN しているか確認
5. 3000番ポートが LISTEN しているか確認
6. Nginx経由で `http://localhost/app/` にアクセスできるか確認
7. 結果を `/var/log/web_stack_check.log` に出力

`systemctl start myapp` の直後は、サービスが active になっていても、アプリケーションが3000番ポートで LISTEN するまでに時間差が出る場合があります。

そのため、自動起動後に `sleep 2` を入れ、少し待ってからポート確認とHTTP確認を行うようにしました。

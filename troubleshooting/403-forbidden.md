## 403 Forbidden　まとめ

ブラウザで curl http://localhost:8080と打ったところ403エラーが出た。

パターン①：　nginx設定ファイルでアクセスの許可禁止
nginx設定ファイルの設定で弾かれている
error.logの一部抜粋 access forbidden by rule

直し方
sudo nano /etc/nginx/sites-enabled/default
deny all; をコメントアウト

パターン②：　指定のいちにファイルがない
ディレクトリまでは存在するがファイルがない。一覧表示が禁止されている
directory index of "/var/www/html/" is forbidden

直し方
指定の位置にファイルを作成しnginx設定ファイルのindexの欄に追加。別のディレクトリに存在しているなら移動
sudo touch /var/www/html/index.html 
sudo mv ~/test/index.html /var/www/html

パターン③：　ファイルがnginx設定ファイルのindexの欄に登録されていない
ログとしてはパターン②と同じログが出る。nginxからしたらないのと同じ
directory index of "/var/www/html/" is forbidden

直し方
nginx設定ファイルのindexの欄にファイルを追加する
sudo nano /etc/nginx/sites-enabled/default
index  index.html;

パターン④：　ファイルまたはそこにたどり着くまでのディレクトリで権限不足
open() "/var/www/html/index.html" failed (13: Permission denied)
ファイルを開くのに失敗したと出ている

直し方
ls -l /var/www/html/index.html
sudo chmod 644 /var/www/html/index.html
ファイルなら読む権利を追加
ディレクトリなら実行権を追加




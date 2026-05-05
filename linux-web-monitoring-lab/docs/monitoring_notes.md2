# 監視スクリプトの学び

## systemctl is-active --quiet

`systemctl is-active --quiet` は、対象サービスがactiveなら終了ステータス0を返す。  
activeでなければ0以外を返す。

そのため、if文でサービス状態を判定できる。

if systemctl is-active --quiet myapp
then
    echo "myapp: OK"
else
    echo "myapp: NG"
fi
grep -q

grep -q は検索結果を画面に表示せず、見つかったかどうかだけを終了ステータスで返す。

ss -tulnp | grep -q ':3000'

3000番が見つかれば0、見つからなければ1を返す。

サービス状態・ポート状態・HTTP応答の違い

サービスがactiveでも、ポートがLISTENしているとは限らない。
ポートがLISTENしていても、Webとして正常な応答が返るとは限らない。

そのため、以下を分けて確認する必要がある。

サービス状態
ポート状態
HTTP応答
自動復旧直後のタイミング差

myapp.service を自動復旧する処理を追加した際、以下のようなログになった。

myapp: NG
action: starting myapp
myapp restart: OK
port 3000: NG

この時、myapp restart: OK となっているため、systemd上では myapp.service はactiveになっていた。
しかし、その直後の ss によるポート確認では3000番がLISTENしていないと判定された。

後から手動で確認すると3000番ポートはLISTENしていたため、systemctl start myapp の直後に、Pythonアプリが3000番で待ち受けるまでのわずかな時間差が原因だと考えた。

対応

systemctl start myapp の直後に sleep 2 を追加した。

systemctl start myapp
sleep 2

これにより、myapp.service 起動後に少し待ってから、ポート確認とHTTP確認へ進むようにした。

学び

systemctl start が完了してサービスがactiveになっていても、アプリケーションがポートでLISTENするまでには少し時間差がある場合がある。

自動復旧直後にポート確認やHTTP確認を行う場合は、sleep やリトライ処理を入れることで、起動直後のタイミング差による誤検知を防げる。

## ver1
```bash
#!/bin/bash

LOG="/var/log/check_webservice.log"
TIME="$(date '+%H%M%d %H:%m:%s')"

echo "=== nginx_check "$TIME"===" >> "$LOG"

#nginx_check
if systemctl is-active --quiet nginx
then
echo "nginx running" >> "$LOG"
else
echo "nginx restarted" >> "$LOG"
systemctl start nginx
fi

#python_check
if systemctl is-active --quiet myapp
then
echo "myapp running" >> "$LOG"
else
echo "myapp restarted" >> "$LOG"
systemctl start myapp
fi
echo "-----------------------" >> "$LOG"
```
### 改善点
- 日付の表記がおかしい
- restartではなくstartしているのでログにもstartingとかく
- 起動後に本当に復旧したか確認すると良い

## ver2
```bash
#!/bin/bash

LOG="/var/log/check_webservice.log"
TIME="$(date '+%Y-%m-%d %H:%M:%S')"

echo "=== webservice check $TIME ===" >> "$LOG"

# nginx check
if systemctl is-active --quiet nginx; then
    echo "nginx: running" >> "$LOG"
else
    echo "nginx: stopped. starting nginx..." >> "$LOG"
    systemctl start nginx

    if systemctl is-active --quiet nginx; then
        echo "nginx: started successfully" >> "$LOG"
    else
        echo "nginx: start failed" >> "$LOG"
    fi
fi

# myapp check
if systemctl is-active --quiet myapp; then
    echo "myapp: running" >> "$LOG"
else
    echo "myapp: stopped. starting myapp..." >> "$LOG"
    systemctl start myapp

    if systemctl is-active --quiet myapp; then
        echo "myapp: started successfully" >> "$LOG"
    else
        echo "myapp: start failed" >> "$LOG"
    fi
fi

echo "-----------------------" >> "$LOG"
```

## さらに付け足すなら
- 80番・3000番ポート確認を入れる ss
- curlでWebページまで確認する curl
curl -fs http://localhost/app/ > /dev/null
-s の意味

-s は silent の略です。

意味は、

余計な進捗表示やエラーメッセージを出さない

です。

普通の curl は、場合によってはダウンロード進捗みたいな表示が出ます。

% Total    % Received ...

監視スクリプトでは、画面に余計な表示はいらないので -s を付けます。

curl -s http://localhost/app/

つまり、

静かにアクセスして

という意味です。

-f の意味

-f は fail の略です。

意味は、

HTTPエラーを失敗として扱う

です。

ここがかなり大事です。

普通の curl だと、404や502のHTMLが返ってきても、

通信自体はできた

と見なして成功扱いになることがあります。

でも監視では、404や502は成功ではありません。

だから -f を付けます。

curl -f http://localhost/app/

こうすると、

200 OK → 成功
404 Not Found → 失敗
502 Bad Gateway → 失敗

として扱えます。

> /dev/null の意味

これは、

取得したHTMLの中身を表示せずに捨てる

という意味です。

監視スクリプトで必要なのは、ページの中身ではなく、

アクセスに成功したか失敗したか

だけです。

だからHTML本文は捨てます。

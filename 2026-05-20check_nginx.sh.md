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


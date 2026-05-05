#!/bin/bash

LOG="/var/log/web_stack_check.log"
TIME="$(date '+%Y-%m-%d %H:%M:%S')"

echo "=== $TIME web stack check ===" >> "$LOG"

# nginx check
if systemctl is-active --quiet nginx
then
    echo "$TIME nginx: OK" >> "$LOG"
else
    echo "$TIME nginx: NG" >> "$LOG"
fi

# myapp check
if systemctl is-active --quiet myapp
then
    echo "$TIME myapp: OK" >> "$LOG"
else
    echo "$TIME myapp: NG" >> "$LOG"
    echo "$TIME action: starting myapp" >> "$LOG"

    systemctl start myapp

    if systemctl is-active --quiet myapp
    then
        echo "$TIME myapp restart: OK" >> "$LOG"
    else
        echo "$TIME myapp restart: NG" >> "$LOG"
    fi
fi

# port 80 check
if ss -tulnp | grep -q ':80'
then
    echo "$TIME port 80: OK" >> "$LOG"
else
    echo "$TIME port 80: NG" >> "$LOG"
fi

# port 3000 check
if ss -tulnp | grep -q ':3000'
then
    echo "$TIME port 3000: OK" >> "$LOG"
else
    echo "$TIME port 3000: NG" >> "$LOG"
fi

# http check
if curl -s http://localhost/app/ | grep -q -i "Hello"
then
    echo "$TIME http check: OK" >> "$LOG"
else
    echo "$TIME http check: NG" >> "$LOG"
fi

echo "" >> "$LOG"

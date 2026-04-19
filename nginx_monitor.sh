#!/bin/bash

if !systemctl is-active --quiet nginx; then
   echo "$(date) nginx is down. restarting..." >> /tmp/nginx_monitor.log
   systemctl start nginx
else
   echo "$(date) nginx is running" >> /tmp/nginx_monitor.log
fi

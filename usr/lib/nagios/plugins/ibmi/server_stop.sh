#!/bin/bash
ps -ef | grep java | grep "name=nagios" | awk '{print $2}' | xargs kill -9
/usr/bin/systemctl stop nagios
echo "Nagios Server stopped"

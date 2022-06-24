#!/bin/bash
ps -ef | grep java | grep "name=nagios" | awk '{print $2}' | xargs kill -9
/usr/bin/systemctl stop nagios
echo "Nagios Server stopped"

pid=$(ps -ef | grep java | grep "name=nagios" | awk '{print $2}')
if ["" = "$pid"] ; then
	echo "Starting Nagios Server"
	nohup java -cp /usr/lib/nagios/plugins/ibmi/jt400.jar:/usr/lib/nagios/plugins/ibmi/nagios4i.jar com.ibm.nagios.Server -dname=nagios >> /var/log/nagios/nagios.log &
	/usr/bin/systemctl start nagios
	echo "Nagios Service Started"
else
	echo "The server is already started"
fi

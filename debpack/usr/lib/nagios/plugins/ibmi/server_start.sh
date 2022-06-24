#!/bin/bash
pid=$(ps -ef | grep java | grep "name=nagios" | awk '{print $2}')
if ["" = "$pid"] ; then
	echo "Starting Nagios Server"
	nohup java -cp /usr/lib/nagios/plugins/ibmi/jt400.jar:/usr/lib/nagios/plugins/ibmi/nagios4i.jar com.ibm.nagios.Server -dname=nagios >> /var/log/nagios/nagios.log &
	/usr/bin/systemctl restart nagios
	echo "Nagios Service Started"
else
	echo "The server is already started"
fi

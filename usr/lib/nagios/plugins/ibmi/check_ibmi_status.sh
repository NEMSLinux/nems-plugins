#!/bin/bash
java -cp /usr/lib/nagios/plugins/ibmi/jt400.jar:/usr/lib/nagios/plugins/ibmi/nagios4i.jar com.ibm.nagios.client.CheckIBMiStatus $*

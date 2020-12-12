#! /bin/bash
export IPADDRESS=`ifconfig eth0 | grep 'inet' | awk '{print $2}'`
test $IPADDRESS
confd -onetime -backend env
cd /opt/ibm/cognos/analytics/app/bin64/
./cogconfig.sh -s
sleep infinity

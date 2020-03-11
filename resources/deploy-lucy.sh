#!/bin/sh

#
# Automatic deployment on Lucy service:
# See: http://lucy1.rd.francetelecom.fr/
#
#
# NOTE: THIS FILE SHOULD NOT BE PUBLISHED
#

cd $(dirname $0)/..

ip=$(ip a show eth0 | sed -n '/inet/s/.*inet \([0-9\.]*\).*$/\1/p' | tr '.' '-')
server_name="pwd${ip}-80.lucy1.rd.francetelecom.fr"

echo "Node ip  : $ip"
echo "Node name: $server_name"

sed -i "s/.*ServerName.*/ServerName $server_name/" conf/apache-fossology-lucy.conf
mv conf/deploy-lucy.conf conf/deploy.conf


./deploy.sh

echo
echo "Full URL: http://$server_name"


#!/bin/sh

#
# Software Name : Fossology Docker Deploy Scripts Suite
# Version: 1.0
# Copyright (c) 2020 Orange
# SPDX-License-Identifier: MIT
#
# This software is distributed under the MIT License
# the text of which is available at https://spdx.org/licenses/MIT.html
# or see the "LICENSE" file for more details.
#
# Author: Nicolas Toussaint nicolas1.toussaint@orange.com
#

# Configure the Web Docker container
# - Install Apache configuration file
# - Install Apache SSL certificates
# - Install /etc/hosts
# - Install debian packages for LDAP or Shibboleth apache modules
# - Apply all required changes in fossology.conf
# - Enable LDAP or Shibboleth Apache modules

docker_container=fossology_web_1
apache_conf_file_target=/etc/apache2/sites-available/fossology.conf
fossology_conf_file_target=/usr/local/etc/fossology/fossology.conf

. ./setup-common.sh
f_check_container

f_log -s "Setup Apache configuration"
[ -n "$apache_conf_file" ] || f_fatal "Missing config. entry 'apache_conf_file'"
[ -r "$apache_conf_file" ] || f_fatal "File missing: '$apache_conf_file'"

f_log "Configure HTTPS certificates"
if [ -n "$ETC_SSL_CERTIFICATE$ETC_SSL_PRIVATE_KEY" ]
then
    [ -r "$ETC_SSL_CERTIFICATE" ] || f_fatal "File missing: '$ETC_SSL_CERTIFICATE'"
    [ -r "$ETC_SSL_PRIVATE_KEY" ] || f_fatal "File missing: '$ETC_SSL_PRIVATE_KEY'"
    docker cp "$ETC_SSL_CERTIFICATE" $docker_container:/etc/ssl/certs/ || f_fatal
    docker cp "$ETC_SSL_PRIVATE_KEY" $docker_container:/etc/ssl/private/ || f_fatal
    docker exec $docker_container a2enmod ssl || f_fatal "Failed to load Apache module"
fi

if [ -n "$add_to_etc_hosts" ]
then
    f_log "Update /etc/hosts"
    [ -s "$add_to_etc_hosts" ] || f_fatal "File missing: '$add_to_etc_hosts'"
    cat "$add_to_etc_hosts" | docker exec -i $docker_container tee -a /etc/hosts || \
        f_fatal "Failed to update /etc/hosts"
fi

if [ "$auth_ldap_enable" = "true" ]
then
    apache_extra_modules="$apache_extra_modules ldap authnz_ldap"
fi

if [ "$auth_shibboleth_enable" = "true" ]
then
    f_log "Setup Shibboleth Authentication"
    docker exec $docker_container apt-get update || f_fatal
    docker exec $docker_container apt-get install -y libapache2-mod-shib2 || f_fatal
    ls $auth_shibboleth_configuration_directory/* >/dev/null 2>&1 \
        || f_fatal "Wrong directory: '$auth_shibboleth_configuration_directory/'"
    for f in $auth_shibboleth_configuration_directory/*
    do
        docker cp $f $docker_container:/etc/shibboleth/ || f_fatal
    done
    docker exec $docker_container service shibd restart
    apache_extra_modules="$apache_extra_modules shib2"
fi

f_log "Update Fossoloy configuration"
for kw in $( sed -n '/^CONF_/s/^\([^=]*\)=.*$/\1/p' $conf_file)
do
    eval "val=\"\$$kw\""
    echo "== $kw: $val"
    docker exec $docker_container sed -i "s/^$kw *=.*/$kw=$val/" \
        $fossology_conf_file_target || f_fatal
done
docker cp $apache_conf_file $docker_container:$apache_conf_file_target || f_fatal

f_log "Enable modules"
for mod in proxy_http $apache_extra_modules
do
    docker exec $docker_container a2enmod $mod || \
        f_fatal "Failed to load Apache module '$mod'"
done
docker exec $docker_container a2ensite fossology || \
    f_fatal "Failed to enable Apache site"
sleep 4 # For some reason, Apache needs some rest, so be it.

f_log "Reload Apache"
docker exec $docker_container service apache2 reload || \
    f_fatal "Failed reloading Apache"


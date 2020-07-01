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

# Configure the Scheduler Docker container
# - copy 'conf/git.config'
# - copy /usr/local/etc/fossology/fossology.conf
# - force usage of s-nail debian package to send emails
# - install custom entries for Keywords searches (from conf/keyword.conf)

docker_container=fossology_scheduler_1

. ./setup-common.sh
f_check_container
do_restart_container=false

f_log -s "Configure scheduler"

### ### ### ### ### ### ### ### ### ###
# GIT Config
git_conf=conf/git.config
if [ -r "$git_conf" ]
then
    f_log "Update GIT configuration"
    # /!\ Not sure if something changed recently, but the home folder
    #     for user 'fossy' seems to have momved from
    #     /srv/fossology to /home/fossy/
    docker cp $git_conf $docker_container:/srv/fossology/.gitconfig || f_fatal
    docker cp $git_conf $docker_container:/home/fossy/.gitconfig || f_fatal
fi
echo


### ### ### ### ### ### ### ### ### ###
# Proxy Config
if [ -r "$proxy_conf" ]
then
    f_log "Update Proxy configuration ($proxy_conf)"
    cat $proxy_conf | \
        docker exec -i $docker_container tee -a /usr/local/etc/fossology/fossology.conf \
        || f_fatal
    do_restart_container=true
fi
echo

### ### ### ### ### ### ### ### ### ###
# Email / SMTP setup
f_log "Force Mailer alternative to s-nail"
docker exec $docker_container update-alternatives --install /usr/bin/mailx mailx /usr/bin/s-nail 90
echo

### ### ### ### ### ### ### ### ### ###
# Keyword search configuration
keyword_conf_target=/usr/local/share/fossology/keyword/agent/keyword.conf
keyword_conf_source=conf/keyword.conf
if [ -r "$keyword_conf_source" ]
then
    f_log "Configure Keyword search list"
    cat $keyword_conf_source | \
        docker exec -i $docker_container tee -a $keyword_conf_target \
        || f_fatal "Error configuring keywork list '$keyword_conf_source'"
fi

# Restart service only once, at end of script
if [ "$do_restart_container" = "true" ]
then
    docker exec -u root $docker_container service fossology restart
    # Exit code 137 means that the container was stopped 
    # Expected behaviour since we asked it to restart
    # It may be that the service was not running yet, and is therefore not stopped
    # in which case exit code 0 is acceptble too
    ret=$?
    [ $ret -eq 137 -o $ret -eq 0 ] || f_fatal "Fossology service restart with exit code $ret"
fi
exit 0

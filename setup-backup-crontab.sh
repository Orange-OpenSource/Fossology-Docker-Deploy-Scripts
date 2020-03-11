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
#
# This file configured a cron task on the HOST (Linux) machine
#  according to the configuration

. ./setup-common.sh

conf_file=$(dirname $0)/conf/docker_backup.conf
[ -r $conf_file ] || f_fatal "Configuration file missing '$conf_file'"
. $conf_file

backup_cmd=docker-backup.sh
backup_cmd_path=$(readlink -f $(dirname $0)/$backup_cmd)
f_log -s "Setup backup crontab entry"

if [ "$docker_backup_crontab_enable" = "true" ]
then

    [ -x "$backup_cmd_path" ] || \
        f_fatal "Backup script is missing ($backup_cmd_path)"

    # Verify that the prefix contains 5 distinct fields
    echo "$docker_backup_crontab_entry_prefix" | \
        sed 's/\s\s*[^$]/\n/g' | wc -l | grep -q 5 || \
        f_fatal "Malformed Crontab entry prefix"

    # Setup crontab for the current user.
    # 1. Output current crontab entries
    # 2. Remove entries referencing the backup script
    # 3. Add a new entry
    # 4. Configure crontab for the current user
 
    { 
        crontab -l | grep -v "$backup_cmd" ;
        echo "$docker_backup_crontab_entry_prefix $backup_cmd_path"
    } | crontab -
    
    f_log "Crontab updated:"
    crontab -l | grep "$backup_cmd"
else
    f_log "Backup crontab not enabled"
fi

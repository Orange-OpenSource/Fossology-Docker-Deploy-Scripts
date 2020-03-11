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

# This file backs up Fossology Docker containers
#
# It expects the containers to be deployed within a Docker
#   project 'fossology'
#   eg. `docker-compose --project-name fossology up`
#
# Configuration stored in conf/docker_backup.conf
#
# The following can be backed-up
# - the configuration files for this script suite
# - Scheduler container: the /repository 
# - Database container: Postgresql db
#


now_tag=$(date +%Y%m%d_%H%M%S)
conf_file=$(dirname $0)/conf/docker_backup.conf
[ -r $conf_file ] || f_fatal "Configuration file missing '$conf_file'"
. $conf_file

. $(dirname $0)/setup-common.sh

exit_code=0
f_result() {
    if [ -s $1 ]
    then
        f_log -l -s "Success : $(ls -sh $1)"
    else
        f_log -l -s "Failure ***"
        exit_code=1
        return 1
    fi
}

# Remove old backups according to configuration
f_clean_old_backups() {
    local nb=$1
    shift
    echo "$nb" | grep -q  '^[0-9][0-9]*$' || \
        f_fatal "Wrong conf entry: '$nb'"

    f_log -l "Remove empty files"
    ls -rt1 "$@" | while read f; do [ -s "$f" ] || rm -v "$f" ; done

    if [ "$nb" -gt 0 ]
    then
        f_log -l "Remove old backups (keep $nb)"
        ls -rt1 "$@" | head -n -$nb | while read f; do rm -v "$f" ; done
    else
        f_log -l "No old backup cleaning configured"
    fi

}

# If configured, run user-specified command upon backup completion
f_hook() {
    if [ -e "$docker_backup_hook" ]
    then
        f_log "Execute post-backup hook: $docker_backup_hook"
        $docker_backup_hook "$1" "$2"
    fi
}

#### #### #### #### #### #### #### #### #### #### #### #### #### ####
### Check that backup is enabled
if echo "$docker_backup_enable" | grep -q '^true$'
then
    f_log -s -l "Backup: Starting"
else
    f_log -s -l "Backup: Disabled"
    exit 0
fi

#### #### #### #### #### #### #### #### #### #### #### #### #### ####
### Backup Local Configuration

if [ -n "$docker_backup_conf_dest_dir" ]
then
    [ -w "$docker_backup_conf_dest_dir" ] || \
        f_fatal -l "Directory not writable: '$docker_backup_conf_dest_dir'."

    dest=$docker_backup_conf_dest_dir/fossology_configuration_${now_tag}.tgz

    f_log -s -l "Perform Configuration Backup"
    f_log -l "Dest file: $dest"

    tar czf $dest -C $(dirname $0) conf
    f_result $dest
    f_clean_old_backups $docker_backup_conf_old_archives_count \
        $docker_backup_conf_dest_dir/fossology_configuration_*.tgz
    f_hook configuration "$dest"
else
    f_log "Not configured ... skipping."
fi

#### #### #### #### #### #### #### #### #### #### #### #### #### ####
### Backup Repository

[ -n "$docker_backup_repo_dest_dir" ] || \
    f_fatal -l "Configuration entry missing."
[ -w "$docker_backup_repo_dest_dir" ] || \
    f_fatal -l "Directory not writable: '$docker_backup_repo_dest_dir'."

dest=$docker_backup_repo_dest_dir/fossology_repository_${now_tag}.tgz
_volume=fossology_repository
_mp=/tmp/srv_fossology_repository # Mount Point inside Docker container

f_log -s -l "Perform Repository Backup"
f_log -l "Dest file: $dest"

docker volume inspect $_volume >/dev/null || \
    f_fatal "Backup failed: unknown volume '$_volume'"
docker run --rm --name fossology_backup \
    -v $_volume:$_mp:ro alpine tar cz -C $_mp . >$dest
f_result $dest

f_clean_old_backups $docker_backup_repo_old_archives_count \
    $docker_backup_repo_dest_dir/fossology_repository_*.tgz
f_hook repository "$dest"

#### #### #### #### #### #### #### #### #### #### #### #### #### ####
### Backup DB
docker_container=fossology_db_1
f_check_container

# Expect from config file="docker_backup_db_dest"
[ -n "$docker_backup_db_dest_dir" ] || \
    f_fatal "Configuration entry missing."
[ -w "$docker_backup_db_dest_dir" ] || \
    f_fatal "Directory not writable: '$docker_backup_db_dest_dir'."
[ -n "$docker_backup_db_password" ] || \
    f_fatal "Configuration entry missing."

db_user=fossy
db_database=fossology
dest=$docker_backup_db_dest_dir/fossology_db_${now_tag}.psql

f_log -l -s "Perform DB Backup"
f_log -l "Dest file: $dest"

docker exec -e PGPASSWORD=fossology $docker_container \
    pg_dump -Fc -h 127.0.0.1 -U fossy fossology > $dest
f_result $dest

f_clean_old_backups $docker_backup_db_old_archives_count \
    $docker_backup_db_dest_dir/fossology_db_*.psql
f_hook database "$dest"


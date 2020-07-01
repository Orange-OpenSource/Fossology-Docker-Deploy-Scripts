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

# This file backs up Fossology Docker containers
#
# It expects the containers to be deployed within a Docker
#   project 'fossology'
#   eg. `docker-compose --project-name fossology up`
#
# Configuration stored in conf/docker_backup.conf
#
# The following can be backed-up
# - The configuration files for this script suite
# - Fossology: Scheduler container: the /repository
# - Fossology: Database container: Postgresql db
# - FossDash : InfluxDB database
#
# The user may specify which items are subject to backup, see a the bottom of the file
# By default, all available items are selected.
#


user_selection=" $* "

now_tag=$(date +%Y%m%d_%H%M%S)
conf_file=$(dirname $0)/conf/docker_backup.conf
[ -r $conf_file ] || f_fatal "Configuration file missing '$conf_file'"
. $conf_file

. $(dirname $0)/setup-common.sh
log_date="true"

exit_code=0
f_result() {
    if [ -s $1 ]
    then
        local result_file=$1
        local shasum_file=$result_file.sha256sum
        f_log -l -s "Success  : $(ls -sh $result_file)"
        sha256sum $result_file >$shasum_file
        sed -i "s!$(dirname $result_file)!!" $shasum_file
        f_log -l "SHA256SUM: $(ls -1 $shasum_file)"
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

### Backup Local Configuration
f_do_backup_conf() {
    dest=$docker_backup_conf_dest_dir/fossology_configuration_${now_tag}.tgz

    f_log -s -l "Perform Configuration Backup"
    f_log -l "Dest file: $dest"

    [ -w "$docker_backup_conf_dest_dir" ] || \
        f_fatal -l "Directory not writable: '$docker_backup_conf_dest_dir'."

    tar czf $dest -C $(dirname $0) conf
    f_result $dest
    f_clean_old_backups $docker_backup_conf_old_archives_count \
        $docker_backup_conf_dest_dir/fossology_configuration_*.tgz
    f_hook configuration "$dest"
}

### Backup Repository
f_do_backup_fossology_repository() {
    dest=$docker_backup_repo_dest_dir/fossology_repository_${now_tag}.tgz
    _volume=fossology_repository
    _mp=/tmp/srv_fossology_repository # Mount Point inside Docker container

    f_log -s -l "Perform Repository Backup"
    f_log -l "Dest file: $dest"

    [ -w "$docker_backup_repo_dest_dir" ] || \
        f_fatal -l "Directory not writable: '$docker_backup_repo_dest_dir'."

    docker volume inspect $_volume >/dev/null || \
        f_fatal "Backup failed: unknown volume '$_volume'"
    docker run --rm --name fossology_backup \
        -v $_volume:$_mp:ro alpine tar cz -C $_mp . >$dest
    f_log -l "Dest file: $dest"
    f_log -l "Verify file"
    tar tzf $dest >/dev/null || f_fatal -l "Error while verifying archive"
    f_result $dest

    f_clean_old_backups $docker_backup_repo_old_archives_count \
        $docker_backup_repo_dest_dir/fossology_repository_*.tgz
    f_hook repository "$dest"
}

### Backup DB
f_do_backup_fossology_db() {
    docker_container=fossology_db_1
    f_check_container

    db_user=fossy
    db_database=fossology
    dest=$docker_backup_db_dest_dir/fossology_db_${now_tag}.psql

    f_log -l -s "Perform DB Backup"
    f_log -l "Dest file: $dest"

    [ -w "$docker_backup_db_dest_dir" ] || \
        f_fatal "Directory not writable: '$docker_backup_db_dest_dir'."
    [ -n "$docker_backup_db_password" ] || \
        f_fatal "Configuration entry missing."

    docker exec -e PGPASSWORD=fossology $docker_container \
        pg_dump -Fc -h 127.0.0.1 -U fossy fossology > $dest
    f_result $dest

    f_clean_old_backups $docker_backup_db_old_archives_count \
        $docker_backup_db_dest_dir/fossology_db_*.psql
    f_hook database "$dest"
}

### Backup  Fossdash/InfluxDB
f_do_backup_influxdb() {
    container=fossdash_influxdb_1
    if docker container ls -f name=$container -q 2>/dev/null
    then

        dest_file_stub=fossdash_influxdb_${now_tag}
        dest=$docker_backup_fossdash_influxdb_dir/$dest_file_stub.tgz

        f_log -s -l "Perform Fossdash / InfluxDB Backup"
        f_log -l "Dest file: $dest"
        internal_back_dir=/tmp/$dest_file_stub

        [ -w "$docker_backup_fossdash_influxdb_dir" ] || \
            f_fatal -l "Directory not writable: '$docker_backup_fossdash_influxdb_dir'."

        docker exec -it $container influxd backup -database fossology_db $internal_back_dir
        docker exec $container tar cz -C $internal_back_dir . > $dest
        # TODO: remove backup inside the container
        f_result $dest
        f_clean_old_backups $docker_backup_fossdash_influxdb_old_archives_count \
            $docker_backup_fossdash_influxdb_dir/fossdash_influxdb_*.tgz
        f_hook fossdash_influxdb "$dest"
    else
        f_log "Fossdash / InfluxDB Backup: No container '$container'"
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

# Check if a particular item should be backed up
# Arg1. Name
# Arg2. Folder path
f_check_selected() {
    # Either the item was selected by name, or all by default
    if ! echo "$user_selection" | grep -q " $1 \|^  $"
    then
        f_log "$1: Not selected  ... skipping."
        return 1
    fi

    if [ -z "$2" ]
    then
        f_log "$1: Not configured ... skipping."
        return 1
    fi
    return 0
}

f_check_selected "configuration"        "$docker_backup_conf_dest_dir" && f_do_backup_conf
f_check_selected "fossology_repository" "$docker_backup_repo_dest_dir" && f_do_backup_repository
f_check_selected "fossology_db"         "$docker_backup_db_dest_dir"   && f_do_backup_db
f_check_selected "fossdash_influxdb"    "$docker_backup_fossdash_influxdb_dir" && f_do_backup_influxdb


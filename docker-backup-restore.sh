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
# This file restores docker containers for fossology

#
# Fossology Restore Procedure.
# 
# 1. Find the location of the backup files as produced by the backup script.
#    - Repository file : fossology_repository_*.tgz
#    - Database file : fossology_db_*.psql
# 2. Deploy a new instance of Fossology
#    - At least the DB container must be up
# 3. Run this restore script
#    - restore.sh <fossology_repository.tgz> <fossology_db.psql>
# 4. Redeploy Fossology with deploy.sh
#

. $(dirname $0)/setup-common.sh

cont_db=fossology_db_1
cont_sched=fossology_scheduler_1
cont_web=fossology_web_1

cat <<EOS

For Restore operation, container:
    $cont_db MUST be running
    $cont_sched will be stopped and removed
    $cont_web will be stopped and removed
EOS

f_usage() {
    echo
    echo "$(basename $0) <fossology_repository.tgz> <fossology_db.psql>"
    echo
    exit 1
}

#### #### #### #### #### #### #### #### #### #### #### #### #### #### 
### Sanity checks

restore_repo_file="$1"
restore_db_file="$2"

[ -n "$restore_repo_file" ] || f_usage
[ -n "$restore_db_file" ]   || f_usage
[ -s "$restore_repo_file" ] || f_fatal "Cannot read file '$restore_repo_file'"
[ -s "$restore_db_file" ]   || f_fatal "Cannot read file '$restore_db_file'"

f_is_container_running() {
    docker container ls --format='{{json .Names}}' | \
        tr -d '"' | grep -q "^$1$"
}
f_is_container_running $cont_db || \
    f_fatal "Container must be running"

f_blinking_warning \
    "About to restore a backup -> this will erase current setup."

for c in $cont_web $cont_sched
do
    if f_is_container_running $c
    then
        f_log "Stop + remove container '$c'"
        docker container stop $c || f_fatal "Failed to stop container $c"
        docker container rm $c || f_fatal "Failed to remove container $c"
    fi
done

docker_volume_repo="fossology_repository"
if docker volume ls --format='{{json .Name}}' | \
    tr -d '"' | grep -q "^$docker_volume_repo$"
then
    f_log "Remove volume: $docker_volume_repo"
    docker volume rm $docker_volume_repo || \
        f_fatal "Volume '$docker_volume_repo' must be removed"
fi

#### #### #### #### #### #### #### #### #### #### #### #### #### ####
### Restore Repository

f_log -s -l "Restore Repository"

_volume=fossology_repository
_mp=/tmp/srv_fossology_repository # Mount Point inside Docker container

f_log "Copy filesystem to volume '$docker_volume_repo'"
cat $restore_repo_file | docker run -i --rm \
    --name fossology_backup \
    -v fossology_repository:$_mp:rw  \
    alpine tar xz -C $_mp || f_fatal "Failure"

#### #### #### #### #### #### #### #### #### #### #### #### #### ####
### Restore DB
f_log -s -l "Restore Database"

db_user=fossy
db_database=fossology

f_log "Remove existing database, if any"
docker exec $cont_db psql -h 127.0.0.1 -U $db_user postgres \
    -c "DROP DATABASE fossology;"
f_log "Restore database"
cat $restore_db_file | docker exec -i $cont_db pg_restore \
    -h 127.0.0.1 -U $db_user -Fc -C -d postgres || \
    f_fatal "Failure"

f_log "Restore process over."
echo
echo "You may now re-deploy Fossology"

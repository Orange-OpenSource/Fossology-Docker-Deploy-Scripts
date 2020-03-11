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
# This file is the main entry point for automated deployment
#
# Usage: ./deploy.sh [docker image]
#

cd $(dirname $0)
. ./setup-common.sh

_compose_file=docker-compose.yml

f_usage()
{
cat <<EOS

Usage: $(basename $0) [-p] [Docker image name]
    -p Do not try to pull a more recent docker image
    -h this help

EOS
exit $1
}

while getopts "ph" opt; do
    case $opt in
    p)  opt_skip_docker_image_pull="true" ; shift ;;
    h)  f_usage 0 ;;
    \?) f_usage 1 ;;
  esac
done

which docker-compose >/dev/null 2>&1 || \
    f_fatal "docker-compose is missing. See https://docs.docker.com/compose/install/"

[ -f "$_compose_file" ] || \
    f_fatal "File `docker-compose.yml`is missing."

f_log -s "Deploy Fossology containers"
docker_image="$1"
if [ "$docker_image" = "default" ]
then
    [ -n "$default_docker_image" ] || \
        f_fatal "No default Docker image configured"
       docker_image="$default_docker_image"
fi
if [ -n "$docker_image" ]
then
    f_log "Hacking the docker-compose to use image: '$docker_image'"
    # Use 'yq', the Yaml editor: https://github.com/mikefarah/yq
    docker run --rm -v ${PWD}:/workdir mikefarah/yq yq write \
        --inplace $_compose_file services.scheduler.image $docker_image
    docker run --rm -v ${PWD}:/workdir mikefarah/yq yq write \
        --inplace $_compose_file services.web.image $docker_image
    echo "Images from the $_compose_file:"
    docker run --rm -v ${PWD}:/workdir mikefarah/yq yq r $_compose_file \
        'services.*.image'
    echo
fi

image_ref=$(docker run --rm -v ${PWD}:/workdir mikefarah/yq yq r $_compose_file 'services.scheduler.image')
if [ -n "$image_ref" ]
then
    # Only "docker pull" if image refers to a remote registry
    if echo "$image_ref" | grep -q '..*/..*:..*$'
    then
        if [ "$opt_skip_docker_image_pull" != "true" ]
        then
            f_log "Pull recent image for '$image_ref'"
            docker pull $image_ref || \
                f_fatal "Docker pull failed : Same player shoots again."
        else
            f_log "Pull recent Docker image: disabled"
        fi
    else
        f_log "Use local image '$image_ref'"
    fi
fi

f_log "Stop + Restart containers"
docker-compose --project-name fossology down
docker-compose --project-name fossology up -d || \
    f_fatal "docker-compose UP failed"

f_log "Show runing containers"
docker-compose ps

f_log -s "Setup containers"
# Setup needed at each deployement,
# because not persisted
./setup-container-web.sh || f_fatal
./setup-container-scheduler.sh || f_fatal
./setup-certificates.sh || f_fatal

# Setup that remain in persistant DB
# Only needed on initial deployement,
# or to reinitialise
./setup-container-db.sh || f_fatal


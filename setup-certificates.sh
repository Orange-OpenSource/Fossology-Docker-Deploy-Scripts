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

# Install additional ca-certificates inside the scheduler container
#  to allow https access to external servers (like Git servers)

docker_container=fossology_scheduler_1
install_cert_script=resources/install-certificates.sh
certificates=resources/ca-certificates

. ./setup-common.sh
f_check_container

f_log -s "Install additional certificates"
if [ -d $certificates ]
then
    docker cp $certificates $docker_container:/root/ || \
        f_fatal "Cannot copy '$certificates'"
    docker cp $install_cert_script $docker_container:/root/ || \
        f_fatal "Cannot copy '$install_cert_script'"
    
    install_script="/root/$(basename $install_cert_script)"
    docker exec -u root $docker_container $install_script || \
        f_fatal "Failed to run '$install_script'"
else
    f_log "No additional certificate to install in '$certificates'"
fi

echo


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
# This file will grant admin power to a given user
# Use: ./maintenance_give-admin-power.sh <username>

docker_container=fossology_db_1
. ./setup-common.sh
f_check_container

[ -n "$1" ] || f_fatal "Usage: $(basename $0) <username>"

# Give Super Cow Power to specified user
f_query "update users set user_perm = 10 where user_name = '$1';"
f_query "select user_pk,user_name,user_email,user_perm from users where user_perm = 10;"

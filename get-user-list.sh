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
# This file lists all users stored in Fossology database.

query="select user_pk, user_name, user_desc, user_perm, user_email from users order by user_pk;"

docker exec fossology_db_1 psql -h localhost fossology fossy -c "$query"


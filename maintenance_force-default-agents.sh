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
# This file will force a predefined list of default agents to
# all users stored in the database.
# Useful to make sure all users use by default a new agent.

docker_container=fossology_db_1
. ./setup-common.sh
f_check_container

# Force the following default agent list to all existing users
agent_list="agent_bucket,agent_copyright,agent_keyword,agent_mimetype,agent_monk,agent_nomos,agent_ojo,agent_shagent";
f_query "update users set user_agent_list = '$agent_list';"

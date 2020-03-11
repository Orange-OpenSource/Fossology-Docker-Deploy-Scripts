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
# This file deletes ALL Docker containers and volumes.
# Only works if configured as a pre-productino environment in 
#  the configuration file.

cd $(dirname $0)

. ./setup-common.sh

f_blinking_warning "About to destroy the universe."

if f_is_production_env
then
    echo "Sorry, this is NOT a PRE-production environment"
    echo "That's making me nervous, quitting."
    exit 1
fi

echo "* Stopping containers"
docker container ls -aq | xargs docker container stop
echo "* Pruning containers"
docker container prune -f
echo "* Pruning volumes"
docker volume prune -f

echo "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --"
echo "Containers:"
docker container ls -a
echo
echo "Volumes:"
docker volume ls
echo
echo "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --"


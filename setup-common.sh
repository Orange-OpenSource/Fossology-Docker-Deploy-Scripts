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


# This file contains common functions to all feature scripts


proxy_conf=./conf/fossology_proxy.conf
conf_file=$(dirname $0)/conf/deploy.conf

f_log() {
    local _logger=false
    for a in "$@"
    do
        case "$1" in
        -s)
            echo "*** *** *** *** *** *** *** *** *** *** *** *** *** *** "
            shift ;;
        -l)
            _logger=true
            shift ;;
        *) break;;
        esac
    done

    echo "*** $*"
    [ "$_logger" = "true" ] && logger "$(basename $0): $*"
}

f_fatal() {
    if [ "$1" = "-l" ]
    then
        shift
        logger "$*"
    fi
    echo "ERROR $0: $*"
    exit 1
}


f_blinking_warning() {
    t_yellow_blink(){ printf  "\033[33;5m"; }
    t_red(){ printf "\033[0;31m"; }
    t_off(){ printf "\033[0m"; }


    echo "$RED"
cat <<EOS
$(t_red)
$*

Current Hostname: $(t_yellow_blink)$(hostname)$(t_red)
Environment: $(t_yellow_blink)$fossology_environment$(t_red)
$(t_off)
Press <Enter> to continue.

EOS
    read foo

}

# Exits with success (code 0) if environment has NOT been declared
# specifically as a PRE-Production environment.
f_is_production_env() {
    [ "$fossology_environment" = "preproduction" ] && return 1
    return 0
}

f_check_container() {
    # Check target container is running
    [ -n "$docker_container" ] || f_fatal "Define target container in variable 'docker_container'"
    docker container ps -qf name=$docker_container >/dev/null || \
        f_fatal "Target container '$docker_container' is not running"
}

f_query() {
    f_check_container || return 1
    docker exec $docker_container psql -h localhost fossology fossy --tuples-only --quiet -c "$1" | sed 's/^ *//'
}

# Use with a query that returns a single count()
# Exits with code 1 if query returns 0, with code 0 otherwise
f_query_row_exists() {
    f_check_container || return 1
    local ret=$(f_query "$1")
    echo "$ret" | grep -q '^[0-9][0-9]*$' || f_fatal "Query returned unexpected data: [$ret]"
    test $ret -ne 0
}

# Remove old files
# Arg1: file pattern
# Arg2: Number of files to keep
f_clean_old_files() {
    [ "$2" -eq 0 ] && return 0
    ls -rt1 $1 | head -n -$2 | while read f; do rm -v "$f" ; done
}

#######################################################################

[ -r $conf_file ] || f_fatal "Configuration file missing '$conf_file'"
. $conf_file

case $fossology_environment in
    production|preproduction) ;;
    *) f_fatal "Missing or incorrect 'fossology_environment' '$fossology_environment'" ;;
esac

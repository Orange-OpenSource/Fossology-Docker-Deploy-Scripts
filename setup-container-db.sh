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

# Configure the Database Docker container
# - on production environment, remove default 'fossy' user
# - rewrite banner message
# - rewrite SMTP configuration
# - installs custom licenses found in resources/licenses folder

docker_container=fossology_db_1

. $(dirname $0)/setup-common.sh
f_check_container

# Only on Production environment, remove default (and admin) account.
user_fossy_from_where_clause="from users where user_pk = 3 and user_name = 'fossy' and user_desc = 'Default Administrator';"
if f_is_production_env
then
    if f_query_row_exists "select count(user_pk) $user_fossy_from_where_clause"
    then
        f_log -s "Production environments: Remove default user 'fossy'"
        f_query "delete $user_fossy_from_where_clause" || f_fatal "Error removing default user"
    fi
fi

f_log -s "Update database configuration"
# Update conf_value in table sysconfig
# Arg 1: Variable Name
# Arg 2: Value
f_update_db_sysconfig() {
    echo -n " - Update $1"
    f_query "update sysconfig set conf_value = '$2' where variablename = '$1';" || \
        f_fatal "Error configuring DB entry '$Update $1'"
}

### ### ### ### ### ### ### ### ### ###
# Banner Config

if [ -n "$fossology_banner_text" ]
then
    f_log "Update banner message: '$fossology_banner_text'"
    f_update_db_sysconfig "BannerMsg" "$fossology_banner_text"
    echo
fi

if [ "$SMTP_enable" = "true" ]
then
    f_log "Configure SMTP - Hostname: $SMTPHostName"
    [ -n "$SMTPHostName" ]   && f_update_db_sysconfig "SMTPHostName" "$SMTPHostName"
    [ -n "$SMTPAuthPasswd" ] && f_update_db_sysconfig "SMTPAuthPasswd" "$SMTPAuthPasswd"
    [ -n "$SMTPSslVerify" ]  && f_update_db_sysconfig "SMTPSslVerify" "$SMTPSslVerify"
    [ -n "$SMTPStartTls" ]   && f_update_db_sysconfig "SMTPStartTls" "$SMTPStartTls"
    [ -n "$SMTPPort" ]       && f_update_db_sysconfig "SMTPPort" "$SMTPPort"
    [ -n "$SMTPAuth" ]       && f_update_db_sysconfig "SMTPAuth" "$SMTPAuth"
    [ -n "$SMTPAuthUser" ]   && f_update_db_sysconfig "SMTPAuthUser" "$SMTPAuthUser"
    echo
fi

f_log -s "Add home brewed licenses to database"
# Insert licenses defined in the 'resources/licenses' files
# Expecting one license entry per file
#
# To create CSV license file, add it via the web interface,
# and then export it to CSV from psql:
#   \copy (select * from license_ref where rf_shortname = 'Orange-Proprietary') \
#    to /tmp/out.csv with csv
#

for csv in $(dirname 0)/resources/licenses/*csv
do
    [ -s "$csv" ] || continue
    f_log "Handle License file: $csv"
    # Note trick to read CSV file,
    # because newlines within CSV fields are encoded with CR characters.
    lic_name=$(grep -z . $csv | cut -z -d ',' -f2)
    lic_md5=$(grep -z . $csv | cut -z -d ',' -f18)
    [ -n "$lic_md5" ] || f_fatal "Problem with licencse file: '$csv'"

    if f_query_row_exists "select count(rf_pk) from license_ref where rf_md5 = '$lic_md5';"
    then
        echo "License already in the DB: $lic_name"
    else
        echo "Adding license: $lic_name"
        # Find new Primary Key
        max_pk=$(f_query "select max(rf_pk) from license_ref;")
        new_pk=$((max_pk+1))
        # Update license file with new Primary Key
        sed -i "s/^\([^,]*,$lic_name,\)/$new_pk,$lic_name,/" $csv || \
            f_fatal "Failed updating $csv"
        docker cp $csv $docker_container:/tmp/
        f_query "\\copy license_ref from '/tmp/$(basename $csv)' csv"
    fi
    exit
done
exit 0


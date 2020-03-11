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

# Example script, ran in the Scheduler container, that will copy 
# all /root/ca-certificates/*pem  to dir_dest=/usr/local/share/ca-certificates/*crt
# and install the certificates

dir_cache=/root/ca-certificates
dir_dest=/usr/local/share/ca-certificates

if ls $dir_cache/*.pem >/dev/null 2>&1
then
    echo " >> Install from local cache"
    dir_tmp=$dir_cache
else
    echo " >> No certificate to install from '$dir_cache'"
    exit 1
fi

echo " >> Move certificates to target"
for f in $dir_tmp/*pem
do mv -v $f $dir_dest/$(basename $f .pem).crt
done

echo " >> Update ca-certificates"
update-ca-certificates

rmdir $dir_tmp

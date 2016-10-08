#!/bin/bash

bin_dir=$(dirname $0)
name=$(basename $0)
action=$(echo $name | cut -d- -f1)
site=$(echo $name | cut -d- -f2)
app=$(echo $name | cut -d- -f3)

if test -z "$app"; then
    for f in ${bin_dir}/${action}-${site}-*; do
        $f
    done
else
    if test "$action" = "reload"; then
        action="reload-or-restart"
    fi
    
    for f in /etc/systemd/system/app-${site}-${app}*; do
        /bin/systemctl "$action" "$(basename $f)"
    done
fi

#!/bin/bash

bin_dir=$(dirname $0)
name=$(basename $0)
action=$(echo $name | cut -d- -f1)
site=$(echo $name | cut -d- -f2)
app=$(echo $name | cut -d- -f3)

if [ "$action" = "deploy" ]; then
    site=$1
    
    if [ -n "$site" ]; then
        f=${bin_dir}/${action}-${site}
        
        [ -f "$f" ] && $f
    else
        for f in ${bin_dir}/${action}-*; do
            $f
        done
    fi

elif test -z "$app"; then
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

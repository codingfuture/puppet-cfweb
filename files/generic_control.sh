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
    /bin/systemctl "$action" "app-${site}-${app}.service"
fi

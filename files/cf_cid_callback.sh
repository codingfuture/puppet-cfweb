#!/bin/bash

DEPLOY_USER=futoin

if [ "$(id -un)" != "${DEPLOY_USER}" ]; then
    echo "Must be called through 'sudo -u ${DEPLOY_USER}'"
    exit 1
fi


TOOL_WHITELIST=""
TOOL_WHITELIST+=" ant"
TOOL_WHITELIST+=" archiva"
TOOL_WHITELIST+=" artifactory"
TOOL_WHITELIST+=" bash"
TOOL_WHITELIST+=" binutils"
TOOL_WHITELIST+=" bower"
TOOL_WHITELIST+=" bundler"
TOOL_WHITELIST+=" bzip2"
TOOL_WHITELIST+=" cargo"
TOOL_WHITELIST+=" cid"
TOOL_WHITELIST+=" cmake"
TOOL_WHITELIST+=" composer"
TOOL_WHITELIST+=" curl"
TOOL_WHITELIST+=" docker"
TOOL_WHITELIST+=" dockercompose"
TOOL_WHITELIST+=" exe"
TOOL_WHITELIST+=" flyway"
TOOL_WHITELIST+=" futoin"
TOOL_WHITELIST+=" gcc"
TOOL_WHITELIST+=" gem"
TOOL_WHITELIST+=" git"
TOOL_WHITELIST+=" go"
TOOL_WHITELIST+=" gpg"
TOOL_WHITELIST+=" gradle"
TOOL_WHITELIST+=" grunt"
TOOL_WHITELIST+=" gulp"
TOOL_WHITELIST+=" gvm"
TOOL_WHITELIST+=" gzip"
TOOL_WHITELIST+=" hg"
TOOL_WHITELIST+=" java"
TOOL_WHITELIST+=" jdk"
TOOL_WHITELIST+=" jfrog"
TOOL_WHITELIST+=" liquibase"
TOOL_WHITELIST+=" make"
TOOL_WHITELIST+=" maven"
TOOL_WHITELIST+=" nexus"
TOOL_WHITELIST+=" nexus3"
TOOL_WHITELIST+=" nginx"
TOOL_WHITELIST+=" node"
TOOL_WHITELIST+=" npm"
TOOL_WHITELIST+=" nvm"
TOOL_WHITELIST+=" php"
TOOL_WHITELIST+=" phpbuild"
TOOL_WHITELIST+=" phpfpm"
# It must be updated inside virtualenv
#TOOL_WHITELIST+=" pip"
TOOL_WHITELIST+=" puma"
TOOL_WHITELIST+=" puppet"
TOOL_WHITELIST+=" python"
TOOL_WHITELIST+=" ruby"
TOOL_WHITELIST+=" rust"
TOOL_WHITELIST+=" rustup"
TOOL_WHITELIST+=" rvm"
TOOL_WHITELIST+=" sbt"
TOOL_WHITELIST+=" scala"
TOOL_WHITELIST+=" scp"
TOOL_WHITELIST+=" sdkman"
TOOL_WHITELIST+=" setuptools"
TOOL_WHITELIST+=" ssh"
TOOL_WHITELIST+=" svn"
TOOL_WHITELIST+=" tar"
TOOL_WHITELIST+=" twine"
TOOL_WHITELIST+=" unzip"
TOOL_WHITELIST+=" uwsgi"
TOOL_WHITELIST+=" virtualenv"
TOOL_WHITELIST+=" webpack"
TOOL_WHITELIST+=" xz"
TOOL_WHITELIST+=" yarn"
TOOL_WHITELIST+=" zip"
TOOL_WHITELIST+=" "

cmd=$1

cd /
export CID_DEPLOY_HOME=/www/tools
umask 0022

case $cmd in
    tool)
        subcmd=$2
        tool=$3
        ver=$4

        case $subcmd in
            install|update)
                if echo $TOOL_WHITELIST | grep -q "$tool"; then
                    cid tool $subcmd $tool $ver
                else
                    echo "Tool $tool is not whitelisted yet"
                fi

                if [ "$tool" = "flyway" ]; then
                    chmod +x $CID_DEPLOY_HOME/flyway/*/flyway
                fi
                ;;
            *)
                echo "Unsupported tool sub-command $subcmd" >&2
                ;;
        esac
        ;;
    build-dep)
        shift
        cid build-dep "$@"
        ;;
    *)
        echo "Unsupported command $cmd" >&2
        exit 1
        ;;
esac

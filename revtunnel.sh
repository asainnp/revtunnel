#!/usr/bin/env bash

[ $(whoami) = 'root' ] || { echo "err: '$0' should be run as root, to simulate systemd"
                            echo "     behaviour and switching to simple user."; exit 1; }
cd $(dirname $0)

. ./config.sh ; dstlogname=$(echo $fulldstlogin | sed 's/^\(.*\)@.*$/\1/')

su $dstlogname ./revtunnelasdstuser.sh "$@"

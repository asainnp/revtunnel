#!/usr/bin/env bash

cd $(dirname $0)
. ./config.sh ; dstlogname=$(echo $fulldstlogin | sed 's/^\(.*\)@.*$/\1/')

case "$(whoami)" in
   $dstlogname) ./revtunnelasdstuser.sh "$@" ;;
          root) su $dstlogname -c ./revtunnelasdstuser.sh "$@" ;;
             *) echo "err, you should be user: $dstlogname (defined in config.sh) or root in order to run this."
                exit 1;
esac

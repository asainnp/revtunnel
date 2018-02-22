#!/usr/bin/env bash

cd $(dirname $0) ; . ./config.sh  # runninguser var

case "$(whoami)" in
   $runninguser) ./revtunnelasdstuser.sh "$@" ;;
           root) id -u $runninguser >/dev/null || { echo "user $runninguser does not exists on current comp."; exit 1; }
                 su $runninguser -c "./revtunnelasdstuser.sh $*" ;;
              *) echo "err, you should be user: $runninguser (defined in config.sh) or root in order to run this."
                 exit 1;
esac

#!/usr/bin/env bash

#do not call this script directly, use revtunnel.sh instead
#0-1-2 -> 1-2-3 ???? ... missing '-c' in su command.

. ./config.sh # 4 variables: fullsrvlogin, tunnelport, fulldstlogin, dsthostname.

loginfull2array() { echo $1 | sed 's/^\(.*\)@\(.*\):\(.*\)$/\1 \2 \3/'; }

sarr=( $(loginfull2array $fullsrvlogin) ) ; srvlogname=${sarr[0]} ; srvip=${sarr[1]} ; srvsshport=${sarr[2]}
darr=( $(loginfull2array $fulldstlogin) ) ; dstlogname=${darr[0]} ; dstip=${darr[1]} ; dstsshport=${darr[2]}

[ "$(whoami)" = "$dstlogname" ] || { echo "err, $0 must be run as user: $dstlogname."; exit 1; }

starttunnel() {           ssh -o 'BatchMode yes' -o 'ExitOnForwardFailure yes' -fNTR $srvip:$tunnelport:$dstip:$dstsshport -p$srvsshport $srvlogname@$srvip ; }
killtunnel()  { pkill -f "ssh .* -fNTR $srvip:$tunnelport"; }
killremote()  { ssh -p$srvsshport $srvlogname@$srvip 'pkill -u $srvlogname sshd'; }
checktunnel() { [ "x$dsthostname" = "x$(ssh -p $tunnelport $srvip hostname)" ] && return 0 || return 1; }
restartall()  { killremote; killtunnel; starttunnel; }

case "$1" in
      starttunnel) starttunnel ;;
       killtunnel) killtunnel  ;;
        startloop) id -u $dstlogname || { echo "user $dstlogname do not exists on current comp."; exit 1; }
                   ./looptunnel.sh > /tmp/lastrevtunnel.log
                   ;;
          restart) restartall  ;;
      checktunnel) checktunnel ; exit $? ;;
         checkssh) killtunnel
   	        if ssh -o 'BatchMode yes' -p$srvsshport $srvlogname@$srvip whoami; then exit 0
   		else
                      echo "err: passwordless 'ssh -p$srvsshport $srvlogname@$srvip' not working"
   		   echo "you should set it up (as user: $dstlogname) with:"
   		   echo "ssh-copy-id -p$srvsshport $srvlogname@$srvip"
                   fi ;;
      checksshfwd) killtunnel ; starttunnel ; result=$? ; killtunnel ; exit $result ;;
   checktunnelcmd) killtunnel ; starttunnel ; 
                   #if checktunnel; then killtunnel; exit 0; 
   	           if ssh -o 'BatchMode yes' -p $tunnelport $srvip hostname; then 
                      if checktunnel; then 
                         killtunnel; exit 0;
                      else
                         echo "err: tunnel seems ok, but hostname value do not mach config's: $dsthostname."; 
                         killtunnel ; exit 1
                      fi
   		   else
                      echo "err: tunnel check failed, probably passwordless ssh to dest comp not working."
                      read -p  "do you want to try ssh-copy-id to $dstlogname? " varreply 
                      case "$varreply" in [Yy]) ssh-copy-id -p$tunnelport $dstlogname@$srvip ;; esac
                      killtunnel ; exit 1
                   fi ;;
                *) echo "unknown param1 '$1', allowed: starttunnel/killtunnel/startloop/restartall/checktunnel/checkssh/checksshfwd/checktunnelcmd."
esac


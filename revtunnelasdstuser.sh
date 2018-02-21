#!/usr/bin/env bash
#do not call this script directly, use revtunnel.sh instead
#0-1-2 -> 1-2-3 ????
. ./config.sh # 4 variables: fullsrvlogin, tunnelport, fulldstlogin, dsthostname.

loginfull2array() { echo $1 | sed 's/^\(.*\)@\(.*\):\(.*\)$/\1 \2 \3/'; }

sarr=( $(loginfull2array $fullsrvlogin) ) ; srvlogname=${sarr[1]} ; srvip=${sarr[2]} ; srvsshport=${sarr[3]}
darr=( $(loginfull2array $fulldstlogin) ) ; dstlogname=${darr[1]} ; dstip=${darr[2]} ; dstsshport=${darr[3]}

[ "$(whoami)" = "$dstlogname" ] || { echo "err, $0 must be run as user: $dstlogname."; exit 1; }

starttunnel() {           ssh -fNTR $srvip:$tunnelport:$dstip:$dstsshport -p$srvsshport $srvlogname@$srvip ; }
killtunnel()  { pkill -f "ssh -fNTR $srvip:$tunnelport"; }
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
	        if ssh -o BatchMode=yes -p$srvsshport $srvlogname@$srvip whoami; then exit 0
		else
                   echo "err: passwordless 'ssh -p$srvsshport $srvlogname@$srvip' not working"
		   echo "you should set it up (as user: $dstlogname) with:"
		   echo "ssh-copy-id -p$srvsshport $srvlogname@$srvip"
                fi ;;
   checktunnelisolated) 
	        killtunnel ; starttunnel ; 
                if checktunnel; then killtunnel; exit 0; 
		else
                   echo "err: tunnel check failed, probably passwordless ssh to this very same comp not working."
                   echo "you should try this set of commands (as user: root, except ssh-copy-id):"
                   echo "   # ./revtunnel.sh killtunnel"
                   echo "   # ./revtunnel.sh starttunnel"
                   echo "   $ ssh-copy-id -p$tunnelport $dstlogname@$srvip   #as user: $dstlogname):"
                   echo "   # ./revtunnel.sh killtunnel"
                   exit 1
                fi ;;
             *) echo "unknown param1 '$1', allowed: startloop/restart/checktunnel/chechssh/checktunnelisolated."
esac


#!/usr/bin/env bash

########## variables: ############################
cd $(dirname $0) ;   . ./config.sh  # 5 vars: runninguser, fullsrvlogin, tunnelport, fulldstlogin, dsthostname.
loggingfile=/tmp/lastrevtunnel.log  # for main loop logging

########## usercheck: ############################
[ $(whoami) = "$runninguser" ] || { echo "this script should be called by user: $runninguser."; exit 1; }

########## functions: ############################
starttunnel() { ssh -o 'BatchMode yes' -o 'ExitOnForwardFailure yes' -fNT \
	            -R $srvip:$tunnelport:$dstip:$dstsshport -p$srvsshport $srvlogname@$srvip; }
killtunnel()  { pkill -f "ssh .* -R $srvip:$tunnelport"; }
killremote()  { ssh -p$srvsshport $srvlogname@$srvip 'pkill -u $srvlogname sshd'; }
checktunnel() { [ "x$dsthostname" = "x$(ssh -p $tunnelport $srvip hostname)" ] && return 0 || return 1; }
restartall()  { killremote; killtunnel; starttunnel; }
mainwhileloop() 
{  printf "$(date): starting $(basename $0)" > $loggingfile
   starttunnel ; dotsok=0 ; dotser=0 
   while true; do
      if checktunnel
         then dotser=0 ; [ $((++dotsok%60)) -eq 1 ] && printf "\n$(date), tunnel is ok, ok30s: "
         else dotsok=0 ; [ $((++dotser%60)) -eq 1 ] && printf "\n$(date), tunnel error, er30s: "
              restartall
      fi
      printf "." ; sleep 30 
   done >> $loggingfile
}
stopmainloop() { pkill -f "$(basename $0) startloop" ; killtunnel; }
checksshsimplenohkey(){ ssh -o 'BatchMode yes' -o 'StrictHostKeyChecking no' -p $3 $1@$2 hostname; return $?; }
checksshsimpleonce()  { ssh -o 'BatchMode yes' -p $3 $1@$2 hostname; return $?; }
checksshsimple()
{  sshuser=$1 ; sshserver=$2 ; sshport=$3 ; sshusp="$1@$2:$3"
   if checksshsimpleonce $@; then return 0 # ok
   else if checksshsimplenohkey $@; then   # no need for ssh-keygen -R $sshserver:$sshport beause...
           return 0  # ...'StrictHostKeyhecking no' will add current and remove prev key if exists
        else
           echo    "err: passwordless ssh to '$sshusp' not working (result=$result)"
           read -p "     do you want to try ssh-copy-id to $sshusp as $(whoami)? " varreply 
           case "$varreply" in [Yy]) ssh-copy-id -p$srvsshport $sshuser@$sshserver ;; esac
	fi
        if checksshsimpleonce $@; then return 0
        else echo "err: passwordless ssh to '$sshusp' still not working."
             echo "     try set it up mannualy, then run make again."
             exit 1
        fi
   fi 
}
loginfull2array() { echo $1 | sed 's/^\(.*\)@\(.*\):\(.*\)$/\1 \2 \3/'; }

########## main switch-case: ####################
sarr=( $(loginfull2array $fullsrvlogin) ) ; srvlogname=${sarr[0]} ; srvip=${sarr[1]} ; srvsshport=${sarr[2]}
darr=( $(loginfull2array $fulldstlogin) ) ; dstlogname=${darr[0]} ; dstip=${darr[1]} ; dstsshport=${darr[2]}

case "$1" in
        startloop) mainwhileloop ;;
         stoploop) stopmainloop  ;;
   ############### checkings for Makefile: ###########################
         checkssh) if checksshsimple $srvlogname $srvip $srvsshport; then echo ...ok; else exit 1; fi ;;
      checksshfwd) killtunnel
                   if starttunnel; then killtunnel ; echo ...ok; exit 0;
                   else
                      echo "err: ssh with forwarding failed, check/kill server-side process who owns port: $tunnelport"
                      echo "     also check that server-side sshd_config contains: GatewayPorts clientspecified."
                      killtunnel; exit 1; 
                   fi ;;
   checktunnelcmd) killtunnel; starttunnel; err=1
                   if checksshsimple $srvlogname $srvip $tunnelport; then 
                      if checktunnel; then  err=0; echo ...ok
                      else echo "err: tunnel seems ok, but hostname value do not mach config's: $dsthostname."; fi
                   fi
                   killtunnel; exit $err ;;
                *) echo "unknown param1 '$1' for revtunnel script."
esac

########## eof. #################################


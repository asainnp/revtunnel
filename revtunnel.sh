#!/usr/bin/env bash
# this script is not called directly, it is called over revtunnel.sh instead for su user-switch

#systemd see just first process, second (su user ...) disapears from its subprocesses,
#so first part of trap will kill 'su user...', and second part in su user... will kill detached ssh.
trap 'jobs -p | xargs -r kill; [ "$mainloopflag" = 1 ] && killtunnel' EXIT 

########## load vars from config.sh: #############
cd $(dirname $0) ;   . ./config.sh  # 5 vars: runninguser, fullsrvlogin, tunnelport, fulldstlogin, dsthostname.
loggingfile=/tmp/lastrevtunnel.log  # for main loop logging
scrbasename=$(basename $0)

########## ensure correct running user: ##########
id -u "$runninguser" >/dev/null || { echo "err: user '$runninguser' does not exists."; exit 1; }
case "$(whoami)" in
   $runninguser) ;; # ok, continue script
           root) su $runninguser -c "$0 $*" ; exit $? ;;
              *) echo "err: you should be user: '$runninguser' (from config.sh) or 'root' in order to run revtunnel."
                 exit 1 ;;
esac

########## functions: ############################
loginfull2array() { echo $1 | sed 's/^\(.*\)@\(.*\):\(.*\)$/\1 \2 \3/'; }
starttunnel() { ssh -o 'BatchMode yes' -o 'ExitOnForwardFailure yes' -fNT \
	            -R $srvip:$tunnelport:$dstip:$dstsshport -p$srvsshport $srvlogname@$srvip; }
killtunnel()  { pkill -f "ssh .* -R $srvip:$tunnelport"; }
killremote()  { ssh -p$srvsshport $srvlogname@$srvip 'pkill -u $srvlogname sshd'; }
checktunnel() { [ "x$dsthostname" = "x$(ssh -p $tunnelport $srvip hostname)" ] && return 0 || return 1; }
restartall()  { killremote; killtunnel; starttunnel; }
mainwhileloop() 
{  printf "$(date): starting $scrbasename" > $loggingfile
   starttunnel ; dotsok=0 ; dotser=0 ;     mainloopflag=1 #for killing detached (-f) ssh
   while true; do
      if checktunnel
         then dotser=0 ; [ $((++dotsok%60)) -eq 1 ] && printf "\n$(date), tunnel is ok, ok30s: "
         else dotsok=0 ; [ $((++dotser%60)) -eq 1 ] && printf "\n$(date), tunnel error, er30s: "
              restartall
      fi
      printf "." ; sleep 30 
   done >> $loggingfile
}
stopmainloop() { pkill -f "$(basename $scrbasename) startloop" ; killtunnel; }
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


#!/usr/bin/env bash

########## variables: ############################
cd $(dirname $0) ;   . ./config.sh  # 5 vars: runninguser,fullsrvlogin,tunnelportno,fulldstlogin,desthostname.
loggingfile=/tmp/lastrevtunnel.log  # for main loop logging
read srvlogname srvip srvsshport dstlogname dstip dstsshport < <(echo "$fullsrvlogin:$fulldstlogin" | tr '@:' ' ') 

########## usercheck: ############################
[ $(whoami) = "$runninguser" ] || { echo "this script should be called by user: $runninguser."; exit 1; }

########## functions: ############################
sshopt()       { echo $1 | sed "s/B/-o BatchMode=yes /; s/S/-o StrictHostKeyChecking=no /; s/E/-o ExitOnForwardFailure=yes /"; }
starttunnel()  { ssh $(sshopt BE) -fNT -R $srvip:$tunnelportno:$dstip:$dstsshport -p$srvsshport $srvlogname@$srvip; }
killtunnel()   { pkill -f "ssh .* -R $srvip:$tunnelportno"; }
killremote()   { ssh -p$srvsshport $srvlogname@$srvip "lsof -ti tcp:$tunnelportno | xargs -r kill"; }
killboth()     { killremote; killtunnel; }
checktunnel()  { [ "$desthostname" = "$(ssh -p $tunnelportno $srvip hostname)" ] && return 0 || return 1; }
restartall()   { killboth; starttunnel; }
startloop() 
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
stoploop()       { pkill -f "$(basename $0) startloop" ; killtunnel; }
checksshonce()   { ssh $(sshopt $4) -p $3 $1@$2 hostname; return $?; }
checksshsimple()
{  sshuser=$1 ; sshserver=$2 ; sshport=$3 ; sshusp="$1@$2:$3"
   if checksshonce $1 $2 $3 B; then return 0 # ok
   else if checksshonce $1 $2 $3 BS; then   # no need for ssh-keygen -R $sshserver:$sshport beause...
           return 0    # ...'StrictHostKeyChecking no' will add current and remove prev key if exists
        else
           echo    "err: passwordless ssh to '$sshusp' not working"
           read -p "     do you want to try ssh-copy-id to $sshusp as $(whoami)? " varreply 
           case "$varreply" in [Yy]) ssh-copy-id -p$srvsshport $sshuser@$sshserver ;; esac
        fi
        if checksshonce $1 $2 $3 B; then return 0
        else echo "err: passwordless ssh to '$sshusp' still not working."
             echo "     try set it up mannualy, then run make again."
             exit 1
        fi
   fi 
}
mylogrotate() { fname="$1"; for i in {7..0}; do [ -e $fname.$i ] && mv $fname.$i $fname.$((i+1)); done 
                [ -e $fname ] && cp $fname $fname.0 && : > $fname; }   # fname +fname.[0-8] = 10 total

########## main switch-case: ####################
case "$1" in
   ########## main params: #########################
        startloop) mylogrotate $loggingfile
                   startloop ;;
         stoploop) stoploop  ;;
   ########## manual-test params: ##################
        starttunnel) starttunnel ;;
         killtunnel) killtunnel  ;;
   ########## params for Makefile: #################
         checkssh) if checksshsimple $srvlogname $srvip $srvsshport; then echo ...ok; else exit 1; fi ;;
      checksshfwd) killtunnel
                   if starttunnel; then killtunnel ; echo ...ok; exit 0;
                   else
                      echo "err: ssh with forwarding failed, check/kill server-side process who owns port: $tunnelportno"
                      echo "     also check that server-side sshd_config contains: GatewayPorts clientspecified."
                      killtunnel; exit 1; 
                   fi ;;
   checktunnelcmd) killtunnel; starttunnel; err=1
                   if checksshsimple $dstlogname $srvip $tunnelportno; then 
                      if checktunnel; then  err=0; echo ...ok
                      else echo "err: tunnel seems ok, but hostname value do not mach config's: $desthostname."; fi
                   fi
                   killtunnel; exit $err ;;
                *) echo "unknown param1 '$1' for revtunnel script."
esac

########## eof. #################################


#!/usr/bin/env bash

########## variables: ############################
cd $(dirname $0) ;   . ./config.sh  # 5 vars: runninguser,fullsrvlogin,tunnelportno,fulldstlogin,desthostname.
loggingfile=/tmp/lastrevtunnel.log  # for main loop logging
read srvuser srvip srvsshport dstuser dstip dstsshport < <(echo "$fullsrvlogin:$fulldstlogin" | tr '@:' ' ')

########## usercheck: ############################
[ $(whoami) = "$runninguser" ] || { echo "this script should be called by user: $runninguser."; exit 1; }

########## functions: ############################
sshopt()       { echo $1 | sed "s/B/-o BatchMode=yes /; s/S/-o StrictHostKeyChecking=no /; s/E/-o ExitOnForwardFailure=yes /"; }
starttunnel()  { ssh $(sshopt BE) -fNT -R $srvip:$tunnelportno:$dstip:$dstsshport -p$srvsshport $srvuser@$srvip; }
killtunnel()   { pkill -f "ssh .* -R $srvip:$tunnelportno"; }
killremote()   { ssh -p$srvsshport $srvuser@$srvip "lsof -ti tcp:$tunnelportno | xargs -r kill"; }
killboth()     { killremote; killtunnel; }
checktunnel()  { [ "$desthostname" = "$(ssh -p $tunnelportno $srvip hostname)" ] && return 0 || return 1; }
testtunnel()   { ssh -p $tunnelportno $srvip; } #for manual test
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
   if checksshonce $1 $2 $3 B ; then return 0; fi # try simple ssh
   if checksshonce $1 $2 $3 BS; then return 0; fi # try ssh with non-strict key checking
   ssh-keygen -R "[$sshserver]:$sshport"          # try removing key, (non-strict checking will add new value automatically)
   if checksshonce $1 $2 $3 BS; then return 0; fi    
   read -p "err:\t passwordless ssh to '$sshusp' not working\n\tdo you want to try ssh-copy-id to $sshusp as $(whoami)? " ans
   echo $answ | grep -iq '^y'     || return 1     # exit fn if user didn't response with y/Y...
   ssh-copy-id -p$sshport $sshuser@$sshserver     # try ssh-copy-id
   if checksshonce $1 $2 $3 B; then  return 0; fi 
   return 1
}
mylogrotate() { fname="$1"; for i in {7..0}; do [ -e $fname.$i ] && mv $fname.$i $fname.$((i+1)); done
                [ -e $fname ] && cp $fname $fname.0 && : > $fname; }   # fname +fname.[0-8] = 10 total

########## main switch-case: ####################
case "$1" in
   ########## main params: #########################
        startloop) mylogrotate $loggingfile; startloop ;;
         stoploop) stoploop    ;;
   ########## params for Makefile's testing: #######
         checkssh) if checksshsimple $srvuser $srvip $srvsshport; then echo ...ok; exit 0; fi
                   echo "err: passwordless ssh to middle-server not working (ssh -p$srvip $srvuser@$srvip)."
                   echo "     Try mannually to correct this." ; exit 1 ;;
      checksshfwd) killtunnel
                   if starttunnel; then killtunnel ; echo ...ok;    exit 0; fi
                   echo "err: ssh with forwarding failed, check/kill server-side process which owns port: $tunnelportno"
                   echo "     also check that server-side sshd_config contains: GatewayPorts clientspecified."
                   killtunnel; exit 1 ;;
   checktunnelcmd) killtunnel; starttunnel
                   if checksshsimple $dstuser $srvip $tunnelportno; then 
                      if checktunnel; then  echo ...ok; killtunnel; exit 0; fi
                      echo "err: tunnel seems ok, but hostname value do not mach config's: $desthostname."
                   else 
                      echo "err: passwordless ssh to end destination not working (ssh -p$tunnelportno $dstuser@$srvip)"
                      echo "     Try mannually to correct this. (use '$0 starttunnel' ...try&correct somehow...  '$0 killtunnel')."
                   fi
                   killtunnel; exit 1 ;;
                *) if type -t "$1" | grep -q function; then echo running "$1"; $1 #if param1 match any function name, run it 
                   else echo "unknown param1 '$1' for revtunnel script."; fi ;;
esac

########## eof. #################################


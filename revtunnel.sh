#!/usr/bin/env bash

########## variables: #######################################################################################
cd $(dirname $0) ;   . ./config.sh  # 6vars: runninguser, srvlogin, tunnport, hostname
                                    #                     dstlogin, addtunnelpairs
read srvuser srvip srvsshport dstuser dstip dstsshport < <(echo "$fullsrvlogin:$fulldstlogin" | tr '@:' ' ')
tunpoints=$srvip:$tunnelportno:$dstip:$dstsshport       # tunnel points for main ssh tunnel
addptsarr=(${addtunnelpairs//:/:$dstip:})               # additional reverse tunnels pairs tunport:dstport
addptsstr="${addptsarr[@]/#/-R $srvip:}"                #   - converted to '-R srvip:tunport:dstip:dstport'
loggingfname=/tmp/lastrevtunnel.log                     # file for main loop logging
hasrootport=no; for i in $tunnelportno ${addptsarr[@]%%:*}; do [ 1024 -gt "$i" ] && hasrootport=yes; done

########## usercheck: #######################################################################################
[ $(whoami) = "$runninguser" ] || { echo "this script should be called by user: $runninguser."; exit 1; }

########## functions: #######################################################################################
sshopt()         { all=(BatchMode=yes StrictHostKeyChecking=no ExitOnForwardFailure=yes)
                   sed "s/-o[^$1][^ $]*//g" <<< ${all[@]/#/-o}; } # B/S/E char in param 1 selects options
starttunnel()    { ssh $(sshopt BE) -fNT -R $tunpoints $addptsstr -p$srvsshport $srvuser@$srvip; }
killtunnel()     { pkill -f "ssh .* $tunpoints"; }
killremote()     { ssh -p$srvsshport $srvuser@$srvip "lsof -ti tcp:$tunnelportno | xargs -r kill"; }
restarttunnel()  { killremote; killtunnel; starttunnel; }
checktunnel()    { [ "$desthostname" = "$(ssh -p $tunnelportno $srvip hostname)" ] && return 0 || return 1; }
testtunnel()     { ssh -p $tunnelportno $srvip; } #for manual test
stoploop()       { pkill -f "$(basename $0) startloop" ; killtunnel; }
checksshonce()   { ssh $(sshopt $4) -p $3 $1@$2 hostname; return $?; }
mylogrotate()    { fname="$1"; for i in {7..0}; do [ -e $fname.$i ] && mv $fname.$i $fname.$((i+1)); done
                   [ -e $fname ] && cp $fname $fname.0 && : > $fname; }   # fname +fname.[0-8] = 10 total
checksshsimple()
{  sshuser=$1 ; sshserver=$2 ; sshport=$3 ; sshusp="$1@$2:$3"
   checksshonce $1 $2 $3 B    && return 0     # try simple ssh
   checksshonce $1 $2 $3 BS   && return 0     # try ssh with non-strict key checking
   ssh-keygen -R "[$sshserver]:$sshport"      # try removing key (non-strict-checking will add new value)
   checksshonce $1 $2 $3 BS   && return 0     # check again
   read -p "err:\t passwordless ssh to '$sshusp' failed\n\ttry ssh-copy-id to $sshusp as $(whoami)? " ans
   echo $ans | grep -iq '^y'  || return 1     # exit function if user response is not y/Y...
   ssh-copy-id -p$sshport $sshuser@$sshserver # try ssh-copy-id
   checksshonce $1 $2 $3 B    && return 0     # check again
   return 1
}
unittest()       
{  killtunnel
   if checksshsimple $srvuser $srvip $srvsshport;   then echo "srv-ssh                     ...ok"
   else printf "err:\tpasswordless ssh to middle-server not working (ssh -p$srvsshport $srvuser@$srvip).\n"
   printf "\tTry mannually to correct this.\n" ; exit 1; fi
   if starttunnel;                                  then echo "srv-ssh-with-tunnel         ...ok"
   else printf "err:\tssh with forwarding failed\n"
        printf "\tcheck/kill server-side process which owns the tunnel port ($tunnelportno), also check\n"
        printf "\tthat server-side sshd_config's GatewayPorts=clientspecified.\n"
        if [ "$hasrootport" = "yes" ]; then
           printf "\t...some of defined tunnel ports are bellow 1024, check "
           if [ "$srvuser" = root ]; then printf "PermitRootLogin param too.\n";
           else printf "$srvuser privileges on $srvip, /or use higher ports, /or try root user.\n"
           fi
        fi
        killtunnel; exit 1
   fi
   if checksshsimple $dstuser $srvip $tunnelportno; then echo "dst-ssh-through-tunnel      ...ok"
   else printf "err:\tpasswordless ssh to end destination not working\n"
        printf "\tcmd='ssh -p$tunnelportno $dstuser@$srvip'. Try mannually to correct it.\n"
        printf "\t(for tunnel-establish use param 'starttunnel/killtunnel\n')";    killtunnel; exit 1; fi
   if checktunnel;                                  then echo "hostname-run-on-destination ...ok"
   else printf "err:\ttunnel seems ok, but hostname value does not match config's value: $desthostname.\n"
                                                                                   killtunnel; exit 1; fi
   killtunnel; exit 0; 
}
startloop()      
{  mylogrotate $loggingfname; printf "$(date): starting $(basename $0)" >> $loggingfname
   starttunnel ; dotsok=0 ; dotser=0
   while true; do if checktunnel     # main looop function, called from systemd service
                     then dotser=0 ; [ $((++dotsok%60)) -eq 1 ] && printf "\n$(date), tunnel is ok, ok30s: "
                     else dotsok=0 ; [ $((++dotser%60)) -eq 1 ] && printf "\n$(date), tunnel error, er30s: "
                          restarttunnel; fi
                  printf "." ; sleep 30
   done >> $loggingfname
}

########## function call by param1: #########################################################################
if type -t "$1" | grep -q function; then echo "running: $1 ${@:2}"; $1 "${@:2}" 
else echo "unknown param1 '$1'"; fi # par1 can be any existing function (main are: startloop and stoploop)

########## eof. #############################################################################################


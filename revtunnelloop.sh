#!/usr/bin/env bash

printf "$(date): starting $0" ; dotsok=0 ; dotser=0
while true; do
   if ./revtunnel.sh checktunnel; then
      dotser=0 ; [ $((++dotsok%60)) -eq 1 ] && printf "\n$(date), tunnel is ok, ok30s: "
   else 
      dotsok=0 ; [ $((++dotser%60)) -eq 1 ] && printf "\n$(date), tunnel error, er30s: "
      ./revtunnel.sh restart
   fi
   printf "." ; sleep 30 
done

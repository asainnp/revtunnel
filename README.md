what?

ssh reverse tunnel in ~100 lines of code.
* no autossh, no systemd-restarts, and no ssh alive-interval configurations

how?
* manually checking ssh tunnel connection correctness every 30 seconds by running 'hostname' on target comp and comparing it with config line.

why?

* because internet examples show's sstemd+autossh+aliveinterval combinations
   * all 3 of them try to 'check if ssh works, and kill it/restart it'
   * alive-interval config are complex, there are server and client side and involves time to test it well.
   * autossh needs aditional monitoring port, or it is useless
* result is that in 1% of situations, reverse tunnel do not works, especialy when wifi is involved, 
  leaving user in helpless and hard to debug situations. Also, someties there was server-side part alive, and client-side killed, 
  which disables future forwarding attemps. Tcp connection is in that situation in TIME_WAIT state, and idealy, there should be 
  some part of client that connects to server and kill's all before next attempts.
* so, for 98% situations, simple `ssh -o ExitOnForwardFailure=yes -R remoteip:tunnelport:localip:localport user@remoteipserver` inside some endless loop, works well.
* for 99% situations there is autossh and keep-alive system (still one or few lines of code)
* `revloop` is trying to solve that last 1% situations, by maybe too big effort (~100 lines code). By doing loop, manually 
  checking if it is ok all way to the end, and killing both sides when needed. 
* it also tries to make installation process simpler, instead of remembering all client and server ssh-cfg options, 
  Makefile indicates known initial problems that usually tooks too much time when correcting them over and over 
  again on different computers. 

installation?
```
git clone https://github.com/asainnp/revtunnel ; cd revtunnel`
cp config.sh.example config.sh ; vim config.sh  # edit ports and addresses
make                      # complete check of configuration and connection
sudo make install         # installing files to /opt/revtunnel and service
```

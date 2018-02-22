what?

ssh reverse tunnel for just one ssh port in ~100 lines of code.
- no autossh, no systemd (except for simplest autostart on boot), and no ssh alive-interval configurations

how?
- manually checking ssh tunnel connection correctness every 30 seconds by running 'hostname' on target comp and comparing it with config line.

why?

- because internet examples show's sstemd+autossh+aliveinterval combinations
      - all 3 of them try to 'check if ssh works, and kill it/restart it'
      - alive-interval config are complex, there are server and client side and involves time to check it well.
- result is that in 1% of situations, reverse tunnel do not worked for me, especialy when wifi is involved, 
  leaving user in helpless and hard to debug situations. 
  Also, someties there was server-side part alive, and client-side killed, which denied future forwarding attemps. 
  Tcp connection was in TIME_WAIT state, and idealy, there should be some part of client that connects to server and kill's all before net attempts.
- so, for 95% situations, simple `ssh -R remoteip:tunnelport:localip:loaclport user@remoteipserver` will work well.
- for 99% situations there is autossh and keep-alive system (still one or few line of code)
- this code is trying to solve all 100% situations, by maybe to huge (over 100 lines code) effort. By doing loop, checking is ok, 
  and killing both side when needed. Makefile also try to indicate initial problems that on every computer tooks too much time.


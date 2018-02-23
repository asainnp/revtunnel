default: all
all: config.sh sshworks sshfwdworks tunnelworks
	@echo "tests passed ok, now you can 'sudo make install'"

sshworks:
	./revtunnel.sh checkssh
sshfwdworks:
	./revtunnel.sh checksshfwd
tunnelworks:
	./revtunnel.sh checktunnelcmd
config.sh:
	$(error config.sh does not exists, you should create it from config.sh.example)

installdir=/opt/revtunnel
systemddir=/etc/systemd/system/multi-user.target.wants
runningusr=$(shell . ./config.sh ; echo $$runninguser)

install:
	[ "$(shell whoami)" = root ]   # or fail
	su $(runningusr) -c make
	mkdir -p $(installdir)
	cp config.sh revtunnel.sh $(installdir)
	sed "s/^User=.*$$/User=$(runningusr)/" revtunnel.service > $(installdir)/revtunnel.service
	ln -sf $(installdir)/revtunnel.service $(systemddir)/revtunnel.service
	systemctl daemon-reload && systemctl start revtunnel ; make show
uninstall:
	systemctl stop revtunnel || true
	rm $(systemddir)/revtunnel.service && systemctl daemon-reload || true
	rm -rf $(installdir)
show:
	systemctl status revtunnel || true
	ps -eo pid,ppid,pgid,user,cmd --sort=start_time | grep '[s]sh\|[l]oop'
kill:
	./revtunnel.sh stoploop || true
reinstall:
	make uninstall ; make install


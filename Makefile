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
	@echo "config.sh does not exists, you should create it from config.sh.example"

installdir=/opt/revtunnel
systemddir=/etc/systemd/system/multi-user.target.wants

install: all
	mkdir -p $(installdir)
	cp config.sh revtunnel.{sh,service} revtunnelasdstuser.sh looprevtunnel.sh $(installdir)
	ln -s $(installdir)/revtunnel.service $(systemddir)/revtunnel.service

uninstall:
	rm -f $(systemddir)/revtunnel.service
	rm -rf $(installdir)

reinstall:
	make uninstall
	make install

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

install: all
	mkdir -p $(installdir)
	cp config.sh revtunnel.sh revtunnel.service $(installdir)
	ln -sf $(installdir)/revtunnel.service $(systemddir)/revtunnel.service
	systemctl daemon-reload && systemctl start revtunnel && systemctl status revtunnel

uninstall:
	systemctl stop revtunnel || true
	rm $(systemddir)/revtunnel.service && systemctl daemon-reload || true
	rm -rf $(installdir)

reinstall:
	make uninstall
	make install

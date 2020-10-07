default: test
test: config.sh unittest
	@echo "tests passed ok, now you can 'sudo make install'"

unittest startloop stoploop starttunnel stoptunnel testtunnel: config.sh
	./revtunnel.sh $@

config.sh:
	$(error $@ does not exists, you should create it from $@.example)
rootrights:
	[ "$(shell whoami)" = root ] # or fail

installdir=/opt/revtunnel
systemddir=/etc/systemd/system/multi-user.target.wants
 usrlibdir=/usr/lib/systemd/system
runningusr=$(shell . ./config.sh ; echo $$runninguser)

install uninstall reinstall: rootrights
install:
	su $(runningusr) -c make
	mkdir -p $(installdir)
	cp config.sh revtunnel.sh $(installdir)
	sed "s/^User=.*$$/User=$(runningusr)/" revtunnel.service > $(installdir)/revtunnel.service
	echo "# this file is copied to $(usrlibdir) which is then soft-linked to $(systemdir)." >> $(installdir)/revtunnel.service
	cp $(installdir)/revtunnel.service $(usrlibdir)/revtunnel.service
	ln -sf $(usrlibdir)/revtunnel.service $(systemddir)/revtunnel.service
	systemctl daemon-reload && systemctl start revtunnel ; make show
uninstall:
	systemctl stop revtunnel || true
	rm $(systemddir)/revtunnel.service && systemctl daemon-reload || true
	rm -rf $(installdir)
show:
	systemctl status revtunnel || true
	ps -eo pid,ppid,pgid,user,cmd --sort=start_time | grep '[s]sh\|[l]oop'
reinstall:
	make uninstall ; make install


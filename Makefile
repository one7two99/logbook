.PHONY: deb man clean
VERSION := $(shell grep '^__version__' logbook | cut -d'"' -f2)

man: logbook.1.gz
logbook.1.gz: man/logbook.1.md
	pandoc -s -t man $< -o logbook.1
	gzip -9 -f logbook.1

deb: man
	equivs-build packaging/debian-control
	@echo "→ logbook_$(VERSION)_all.deb gebaut"

clean:
	rm -f logbook.1 logbook.1.gz logbook_*.deb logbook_*.changes logbook_*.buildinfo

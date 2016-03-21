INSTALLDIR = ../steps/

SRCS := $(wildcard *.cc)
BINS := $(SRCS:%.cc=%)

all: $(BINS) install

include config.mk
config.mk:
	@echo 'Creating configuration file $@...'
	@printf 'Enter the include directory of OpenFST: '; IFS= read -r dir && [ -n "$$dir" ] && printf 'FSTDIR=%s\n' "$$dir" > $@
# Example values for FSTDIR:
#     /usr/local/include
#     /ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/include
# Other user- or host-dependent values should also go into this file config.mk.
	@echo 'Created configuration file $@.'

CC = g++
CFLAGS = -Wall -O3 -std=c++11 -I$(FSTDIR)

$(BINS): % : %.cc config.mk
	$(CC) $(CFLAGS) $< -o $@

install: $(BINS)
	cp -u $(BINS) $(INSTALLDIR)

.PHONY: install

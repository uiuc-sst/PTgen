INSTALLDIR=../steps/
FSTDIR=/usr/local/include # for fst/compat.h
#FSTDIR=/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/include # for fst/compat.h

CC=g++
CFLAGS=-Wall -O3 -I$(FSTDIR)

SRCS := $(wildcard *.cc)
BINS := $(SRCS:%.cc=%)

all: $(BINS) install

$(BINS): % : %.cc
	@$(CC) $(CFLAGS) $< -o $@
	@echo "Compiled "$<"."

install: $(BINS)
	cp -u $(BINS) $(INSTALLDIR)

.PHONY: install

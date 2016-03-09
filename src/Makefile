INSTALLDIR=../steps/
FSTDIR=/usr/local/include # for fst/compat.h

CC=g++
CFLAGS=-Wall -O3 -std=c++11 -I$(FSTDIR)

SRCS := $(wildcard *.cc)
BINS := $(SRCS:%.cc=%)

all: $(BINS) install

$(BINS): % : %.cc
	@$(CC) $(CFLAGS) $< -o $@
	@echo "Compiled "$<"."

install: $(BINS)
	cp -u $(BINS) $(INSTALLDIR)

.PHONY: install

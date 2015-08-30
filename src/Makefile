CC=g++
CFLAGS=-Wall
INSTALLDIR=../steps/


SRCS := $(wildcard *.cc)
BINS := $(SRCS:%.cc=%)


all: $(BINS) install

$(BINS): % : %.cc
	@$(CC) $(CFLAGS) $< -o $@
	@echo "Compiled "$<" successfully!"

install: $(BINS)
	mv $(BINS) $(INSTALLDIR)

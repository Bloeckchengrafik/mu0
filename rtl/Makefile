.PHONY: FORCE

.DEFAULT_GOAL := build

ENV ?= default

ifeq ($(ENV),default)
	OPENFPGALOADER_PARAMS = -c ft2232
endif

build: FORCE
	apio build -e $(ENV)

clean: FORCE
	apio clean

program: build FORCE
	openFPGALoader $(OPENFPGALOADER_PARAMS) _build/$(ENV)/hardware.bit

install-apio-uv: FORCE
	uv add 'apio @ git+https://github.com/FPGAwars/apio.git@v1.5.0'

# Executes the dc script for the current OS (win: dc.ps1, linux/mac: dc.sh)

ifeq ($(OS),Windows_NT)
	detected_OS := Windows
	FixPath = $(subst /,\,$1)
	ext = .ps1
else
	detected_OS := $(shell uname)
	FixPath = $1
	ext = .sh
endif

SCRIPT = $(call FixPath,./dc$(ext))

enter:
	@$(SCRIPT) enter $(filter-out $@,$(MAKECMDGOALS))

generate:
	@$(SCRIPT) generate $(filter-out $@,$(MAKECMDGOALS))

%:
	@$(SCRIPT) $@
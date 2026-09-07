# nvim config maintenance targets. None of this is needed to *use* the config.
.PHONY: init doc docs test check doctor ctx clean help
.DEFAULT_GOAL := help

VIM  ?= vim
NVIM ?= nvim
DOCNAME := mikevim

help:  ## list targets
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | expand -t20

init:  ## install plugins in both editors
	-$(NVIM) --headless -c 'PlugInstall --sync' -c 'qa' </dev/null 2>&1 | tail -3
	-$(VIM) -es -N -c 'PlugInstall --sync' -c 'qa' </dev/null 2>&1 | tail -3

doc:  ## regenerate doc/mikevim.txt and doc/tags from README.md
	@command -v pandoc >/dev/null || { echo "pandoc missing: brew install pandoc"; exit 1; }
	@test -f deps/panvimdoc/panvimdoc.sh || { echo "run: git submodule update --init"; exit 1; }
	cd deps/panvimdoc && ./panvimdoc.sh \
		--project-name $(DOCNAME) \
		--input-file ../../README.md \
		--vim-version "Vim 9 / Neovim 0.12" \
		--toc true \
		--description "Mike Dacre dual Vim/NeoVim config" \
		--dedup-subheadings false \
		--demojify true
	@mkdir -p doc && mv -f deps/panvimdoc/doc/$(DOCNAME).txt doc/$(DOCNAME).txt
	@if command -v $(NVIM) >/dev/null 2>&1; then $(NVIM) --headless -c 'helptags doc' -c 'qa'; \
	 else $(VIM) -es -N -c 'helptags doc' -c 'qa' </dev/null; fi
	@echo "doc/$(DOCNAME).txt regenerated. :help $(DOCNAME)"

test:  ## both editors must start cleanly with this config (honest exit codes)
	@bash scripts/check.local.sh

docs: doc  ## alias: what the kit's session.sh end calls

check:  ## the gate
	@bash scripts/check.sh

doctor:  ## toolchain and auth
	@bash scripts/doctor.sh

ctx:  ## print the session digest (no network)
	@bash scripts/session.sh ctx

clean:  ## delete generated docs; regenerate with make doc
	rm -f doc/$(DOCNAME).txt doc/tags

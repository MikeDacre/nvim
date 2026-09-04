# nvim config maintenance targets. None of this is needed to *use* the config.
.PHONY: init doc test check doctor clean help
.DEFAULT_GOAL := help

VIM  ?= vim
NVIM ?= nvim
DOCNAME := mikevim

help:  ## list targets
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | expand -t20

init:  ## install plugins in both editors
	$(NVIM) --headless -c 'PlugInstall --sync' -c 'qa' 2>&1 | tail -3
	-$(VIM) -es -c 'PlugInstall --sync' -c 'qa' 2>&1 | tail -3

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
	$(NVIM) --headless -c 'helptags doc' -c 'qa'
	@echo "doc/$(DOCNAME).txt regenerated. :help $(DOCNAME)"

test:  ## both editors must start cleanly with this config
	@$(NVIM) --headless -u init.vim -c 'qa' && echo "ok  nvim starts"
	@timeout 30 $(VIM) -es --cmd 'set nocompatible' -u init.vim -c 'qa' </dev/null && echo "ok  vim starts"

check:  ## the gate
	@bash scripts/check.sh

doctor:  ## toolchain and auth
	@bash scripts/doctor.sh

clean:  ## delete generated docs, regenerate with make doc
	git clean -f doc/$(DOCNAME).txt doc/tags

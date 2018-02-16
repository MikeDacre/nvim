# Mike Dacre's NeoVim Config

This is a remake of my [vim config](https://github.com/MikeDacre/.vim) to use
neovim initialized in February of 2018 because my vim config was too bloated
and vim was getting just too damned slow.

## Installation

This config contains files for nvim, vanilla vim, and
[ONI](https://github.com/onivim/oni). The core init file `nvim.ini`, can be
used directly as a vimrc. To install this package directly for all vims, do
the following:

```shell
cd $HOME
git clone https://github.com/MikeDacre/nvim $HOME/nvim
ln -s nvim .vim
ln -s nvim/init.vim .vimrc
mkdir -p .oni
ln -s $HOME/nvim/config.js $HOME/.oni/config.js
# Unnecessary on some systems
mkdir -p .config
cd .config
ln -s $HOME/nvim nvim
```

### Installing plugins

Now open first `nvim` and run `:PlugInstall` and then `vim` and run
`:PlugInstall` again, this is because there are slightly different plugins in
vim and nvim to provide the same functionality.

**Note**: The tmux plugins will only be installed if you are in a tmux
environment, so make sure that you are inside tmux if you want to install or
update those plugins.

Two plugins are controlled by environmental variables, the autocompleter, which
defaults to deoplete and switches to YouCompleteMe if `$VIM_YCM` is set, and
markdown-preview, which requires the rust language and is only on if
`$VIM_MARKDOWN` is set. To install both of these, export those two
environmental variables prior to running `PlugInstall` or `PlugUpdate`.

**Note**: Markdown preview requires the rust language to build and
YouCompleteMe requires a modern version of CMAKE, I can't get it to install
on most CentOS systems, which is why the VimCompletesMe fallback exists.

## Little tricks

As described above, I use environmental variables to control some aspects of
the config. To switch to using markdown-composer or YCM, use the variables 
described above. To run a slimmed down version of vim with way fewer plugins,
set the `$VIM_MINIMAL` variable.

## Licensing/Usage

Anything that I have written, you can use for free without crediting me, I
don't care.  Any submodules/plugins are not mine and so everything there is
licensed by the actual authors.

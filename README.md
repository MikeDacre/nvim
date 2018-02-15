# Mike Dacre's NeoVim Config

This is a remake of my [vim config](https://github.com/MikeDacre/.vim) to use
neovim initialized in February of 2018 because my vim config was too bloated
and vim was getting just too damned slow.

Anything that I have written, you can use for free without crediting me, I
don't care.  Any submodules/plugins are not mine and so everything there is
licensed by the actual authors.

This can be used with either nvim or vanilla vim (preferably over version 8).
To do both, clone this repo to `$HOME/nvim`, symlink it to your config location
(e.g. `$HOME/.config/nvim`) and then symlink the vimrc `ln -s $HOME/nvim
~/.vimrc`.

Now open first `nvim` and run `:PlugInstall` and then `vim` and run
`:PlugInstall` again, this is because there are slightly different plugins in
vim and nvim to provide the same functionality.

# zsh-plugin-manager

This is yet another plugin manager, because I did not find any that I was satisfied with.

Focus is on speed and simplicity. That means it is not as polished as [zplug/zplug](https://github.com/zplug/zplug) nor as customizable as [zdharma/zinit](https://github.com/zdharma/zinit).

It supports asynchronous loading and automatically byte compiles your plugins.

## Installation

It works by first sourcing the plugin manager. If you do not have it installed, you can put this snippet in your .zshrc to automatically install it:

```
if [[ ! -d ${ZDOTDIR}/plugins ]]; then
    git clone --depth=1 https://github.com/trobjo/zsh-plugin-manager 2> /dev/null "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager"
    command chmod g-rwX "${ZDOTDIR}/plugins"
fi
source "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager/zsh-plugin-manager.zsh"

```

## Installing a plugin
You install plugins by first declaring them. Declaring a plugin simply means adding it to a list that will be loaded later. 
The syntax for declaring a plugin is as simple as:

```
plug trobjo/zsh-completions
```
The plugin name can be either:
1. github-author/repo
2. http-address. Will not be cloned with git but curl'ed. Does not support updating later.
3. other git repo. Must be prefixed with git@

After declaring 0 or more plugins you can initialize the plugin manager by calling `plug init`. Plugins declared after `plug init` will not be loaded upon initialization of your shell.

## Asynchronous plugins

There are two ways of loading plugins; synchronously and asynchronously.

Asynchronous plugins make the plugins load in the background and therefore make the prompt load way faster. That is especially useful on slow machines, but some plugins must be loaded on initialization, for example the prompt setup.

An asynchronous plugin is declared by adding the `async` keyword after `plug `. It uses [romkatv/zsh-defer](https://github.com/romkatv/zsh-defer) behind the scenes.

## Other options
You can further qualify the installation of a plugin with the use of keywords.

The syntax is `plug [async] <plugin-github-name>[, <qualifier-0>:'<value-0>', <qualifier-1>:'<value-1>', ...]`.

The value should, if it contains anything other than alphabetic characters, be quoted with single quotes.

| Qualifier | Description |
|:-:|-|
|`if` |The expression will be evaluated by your shell and must return an exit code of 0 in order for the plugin to be installed and/or loaded.|
|`ignorelevel`|If you do not want to automatically source the plugin file, for example because it is a binary, you can set the `ignorelevel`.|
|`postinstall`|A shell expression that is run once after the installation.|
|`source`|File to source if the plugin is named differently than `github/name.plugin.zsh` or `github/name.zsh`|
|`postload`|Hook to run on every start after the plugin itself is sourced|
|`env`|Simple environment variables to export. Global|
|`where`|Alternative plugin location.|

## Example
Here is a short, working example:

```
if [[ ! -d ${ZDOTDIR}/plugins ]]; then
    git clone --depth=1 https://github.com/trobjo/zsh-plugin-manager 2> /dev/null "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager"
    command chmod g-rwX "${ZDOTDIR}/plugins"
    mkdir -p "${HOME}/.local/bin"
fi

source "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager/zsh-plugin-manager.zsh"

plug romkatv/gitstatus
plug trobjo/zsh-prompt-compact

plug async trobjo/zsh-completions
plug async skywind3000/z.lua,\
           if:'command -v lua',\
           env:'_ZL_CMD=h',\
           env:'_ZL_DATA=${ZDOTDIR}/zlua_data',\
           ignorelevel:ignore,\
           postload:'$(lua ${plugin_dir_local_location}/z.lua --init zsh enhanced once); _zlua_precmd() {(czmod --add "\${PWD:a}" &) }'
plug async 'https://raw.githubusercontent.com/trobjo/czmod-compiled/master/czmod',\
           if:'! command -v czmod && command -v lua',\
           ignorelevel:ignore,\
           postinstall:'chmod +x "${filename}" && mv ${filename} ${HOME}/.local/bin/'
plug async le0me55i/zsh-extract,\
           source:extract.plugin.zsh
plug async 'https://github.com/junegunn/fzf/releases/download/0.26.0/fzf-0.26.0-linux_amd64.tar.gz',\
           if:'! command -v fzf',\
           ignorelevel:ignore,\
           postinstall:'tar zxvf ${filename} --directory ${HOME}/.local/bin/ && rm ${filename}'
plug async trobjo/Neovim-config,\
           if:'command -v nvim',\
           where:'$XDG_CONFIG_HOME/nvim',\
           postinstall:'nvim +PlugInstall +qall; printf "\e[6 q\n\n"',\
           ignorelevel:ignore

plug init
```

There are probably a lot of bugs, as I have not tested it with any other setups than mine.

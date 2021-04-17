# zsh-plugin-manager

This is yet another plugin manager, because I did not find any that I was satisfied with.

Focus is on speed and simplicity. That means it is not as polished as [zplug/zplug](https://github.com/zplug/zplug) nor as customizable as [zdharma/zinit](https://github.com/zdharma/zinit).

It supports asynchronous loading and automatically byte compiles your plugins.

## Installation

It works by first sourcing the plugin manager. If you do not have it installed, you can put this snippet in your .zshrc to automatically install it:

```zsh
if [[ ! -d ${ZDOTDIR}/plugins ]]; then
    git clone --depth=1 https://github.com/trobjo/zsh-plugin-manager 2> /dev/null "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager"
    command chmod g-rwX "${ZDOTDIR}/plugins"
fi
source "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager/zsh-plugin-manager.zsh"

```

## Installing a plugin
You install plugins by first declaring them. Declaring a plugin simply means adding it to a list that will be loaded later. 
The syntax for declaring a plugin is as simple as:

```zsh
plug trobjo/zsh-completions
```
The plugin name can be either:
1. github-author/repo
2. http-address. Will not be cloned with git but curl'ed. Does not support updating later.
3. other git repo. Must be prefixed with git@

After declaring 0 or more plugins you can initialize the plugin manager by calling `plug init`. Plugins declared after `plug init` will not be loaded.

## Asynchronous plugins

There are two ways of loading plugins; synchronously and asynchronously.

Asynchronous plugins make the plugins load in the background and therefore make the prompt load way faster. That is especially useful on slow machines, but some plugins must be loaded on initialization, for example the prompt setup.

An asynchronous plugin is declared by adding the `async` keyword after `plug `. It uses [romkatv/zsh-defer](https://github.com/romkatv/zsh-defer) behind the scenes.

## Other options
You can further qualify the installation of a plugin with the use of keywords. The syntax is:
```
plug [async] <plugin-github-name>[, <qualifier-0>:'<value-0>', <qualifier-1>:'<value-1>', ...]
```

The value should, if it contains anything other than alphabetic characters, be quoted with single quotes.

The separator value is `, ` – a comma with at least one space.

| Qualifier | Can be used multiple times? | Description |
|:-:|:-:|-|
|`if` |Yes|The expression will be evaluated by your shell and must return an exit code of 0 in order for the plugin to be installed and/or loaded.|
|`env`|Yes|Simple environment variables to export. Exported after sourcing of the plugin and only if plugin loading is without errors|
|`postinstall`|Yes|A shell expression that is run once after the installation.|
|`postload`|Yes|Hook to run on every start after the plugin itself is sourced|
|`nosource`|No|If you do not want to automatically source the plugin file, for example because it is a binary, you can set `nosource=true`.|
|`where`|No|Alternative plugin location.|

## Example
Here is a short, working example:

```zsh
if [[ ! -d ${ZDOTDIR}/plugins ]]; then
    git clone --depth=1 https://github.com/trobjo/zsh-plugin-manager 2> /dev/null "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager"
    command chmod g-rwX "${ZDOTDIR}/plugins"
    mkdir -p "${HOME}/.local/bin"
fi

source "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager/zsh-plugin-manager.zsh"

plug romkatv/gitstatus
plug trobjo/zsh-prompt-compact

plug async trobjo/zsh-completions
plug async 'https://github.com/junegunn/fzf/releases/download/0.26.0/fzf-0.26.0-linux_amd64.tar.gz',\
           if:'! command -v fzf',\
           nosource:true,\
           postinstall:'tar zxvf ${filename} --directory ${HOME}/.local/bin/ && rm ${filename}'
plug async trobjo/Neovim-config,\
           if:'command -v nvim',\
           where:'$XDG_CONFIG_HOME/nvim',\
           postinstall:'nvim +PlugInstall +qall; printf "\e[6 q\n\n"',\
           nosource:true

plug init
```

There are probably a lot of bugs, as I have not tested it with any other setups than mine.

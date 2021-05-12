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

Asynchronous plugins make the plugins load in the background and therefore make the prompt load way faster. That is especially useful on slow machines, but it might cause problems with certain plugins.

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
|`postinstall`|Yes|A shell expression that is run once after the installation.|
|`preload`|Yes|Hook to run on every start before the plugin itself is sourced|
|`postload`|Yes|Hook to run on every start after the plugin itself is sourced|
|`nosource`|No|If you do not want to automatically source the plugin file, for example because it is a binary, you can set `nosource=true`.|
|`where`|No|Alternative plugin location.|

## Example
Here is a short, working example:

```zsh
# Otherwise we cannot load the prompt asynchronously
setopt no_prompt_bang prompt_percent prompt_subst

if [[ ! -d ${ZDOTDIR}/plugins ]]; then
    git clone --depth=1 https://github.com/trobjo/zsh-plugin-manager 2> /dev/null "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager"
    command chmod g-rwX "${ZDOTDIR}/plugins"
    [ ! -d "${HOME}/.local/bin" ] && mkdir -p "${HOME}/.local/bin"
fi
source "${ZDOTDIR}/plugins/trobjo/zsh-plugin-manager/zsh-plugin-manager.zsh"

plug trobjo/zsh-completions
plug async romkatv/gitstatus
plug async zsh-users/zsh-syntax-highlighting
plug async 'zsh-users/zsh-autosuggestions',\
            postload:'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=5,underline',\
            postload:'ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(go_home bracketed-paste-url-magic url-quote-magic
                    repeat-last-command-or-complete-entry expand-or-complete)'
plug async trobjo/zsh-prompt-compact,\
           preload:'[ $PopUp ] && PROHIBIT_TERM_TITLE=true',\
           preload:'READ_ONLY_ICON=""'

plug init
```

There are probably a lot of bugs, as I have not tested it with any other setups than mine.

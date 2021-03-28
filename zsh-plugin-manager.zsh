#
## PLUGIN MANAGER
#

# plugin_manager documentation:
# arguments can be passed to plugin_manager separated by ','.
# The second field is the name of the file to source if it is
# named differently than the plugin. The third field may contain
# a command that must return exit code 0 for the plugin to load.
# For example, you can avoid loading plugins if dependencies are
# not found in $PATH.
# The fourth field contains post-init hooks.

declare -aU __synchronous_plugins
declare -aU __asynchronous_plugins
declare -aU files_to_compile=("${ZDOTDIR:-$HOME}/.zshrc" "${ZDOTDIR:-$HOME}/.zcompdump")

export PLUGROOT="${ZDOTDIR}/plugins"

plug() {
    local myvar="$@"
    case "${1}" in
        (init)
            if [[ -n ${__asynchronous_plugins} ]]; then
                plug romkatv/zsh-defer
                __plug init ${__synchronous_plugins}
                zsh-defer -1 __plug init ${__asynchronous_plugins}
            elif [[ -n ${__synchronous_plugins} ]]; then
                __plug init ${__synchronous_plugins}
            fi
            compile_or_recompile ${files_to_compile}
            ;;
        (update)
           if [[ ${#[@]} -gt 1 ]]; then
                shift
                for plugin in "$@"; do
                    echo $plugin
                    echo ${__synchronous_plugins}
                    if (( ${__synchronous_plugins[(r)plugin*]} )); then
                    echo "it's in"
                else
                    echo "it's somewhere else maybe"
                fi
                    # __plug update ${@}
                done

           else
                __plug update ${__synchronous_plugins} ${__asynchronous_plugins}
           fi
            compile_or_recompile ${files_to_compile}
            ;;
        (install)
            echo to come
            # __plug install ${__synchronous_plugins} ${__asynchronous_plugins}
            if [[ ${#[@]} -gt 1  ]]; then
                printf "\r\x1B[31mCannot install plugins interactively, please load from .zshrc\033[0m\n"
            fi
            ;;
        (async)
            shift
            __asynchronous_plugins+=${${myvar//,[[:blank:]]/│}:6}
            ;;
        (*)
            if [[ ${myvar} != *"/"* ]]; then
                printf "\r\x1B[3m${myvar}\033[0m does not look like a plugin and is not an action\033[0m\n"
                return 1
            fi
            __synchronous_plugins+=${myvar//,[[:blank:]]/│}
            ;;
    esac
}


compile_or_recompile() {
    local file
    for file in "$@"; do
        if [[ -f $file ]] && [[ ! -f ${file}.zwc ]] \
            || [[ $file -nt ${file}.zwc ]]; then
                zcompile "$file"
            fi
        done
    }

__plug() {
    local myarr=($@)
    set --

    local plugin
    for plugin in "${myarr[@]:1}"; do
        unset ignorelevel filename plugindir postload_hook github_name postinstall_hook key value where
        # split strings by args
        parts=("${(@s[│])plugin}")
        local github_name="${parts[1]}"

        for part in "${parts[@]:1}"; do

            key="${part%%:*}"
            value="${part#*:}"
            case "${key}" in
                (if)
                eval "${value}" > /dev/null 2>&1 || continue 2
                ;;
                (ignorelevel)
                local ignorelevel="${value}"
                ;;
                (postinstall_hook)
                local postinstall_hook="${(e)value}"
                ;;
                (postload_hook)
                local postload_hook="${value}"
                ;;
                (env)
                export "${(e)value}"
                ;;
                (where)
                local where="${(e)value}"
                ;;
                (filename)
                local filename="${(e)value}"
                ;;
                (*)
                printf "\x1B[31mDid not understand \033[0m\""${part}"\"\nSkipping \x1B[35m"${github_name}"\033[0m plugin\n"
                continue 2
                ;;
            esac
        done


        if [ -z $where ]; then
            plugindir="${ZDOTDIR}/plugins/$github_name"
        else
            plugindir=${where}
        fi

        local action="${myarr[1]}"
        if [[ $action == 'update' ]]; then
            updater "${github_name}" "${plugindir}" || continue
        elif [[ $action == 'init' ]]; then
            installer "${plugindir}" "${github_name}" "${postinstall_hook}" || continue
        fi

        sourcer "${ignorelevel}" "${filename}" "${plugindir}" "${postload_hook}"
    done
}

installer() {
    local plugindir="$1" pluginname="$2" postinstall_hook="$3"
    if [[ ! -d $1 ]]; then

        printf "\rInstalling \x1B[35m\033[3m${(r:39:)pluginname}\033[0m … "

        if git clone -–depth 1 https://github.com/$pluginname.git ${plugindir} 2> /dev/null; then
            printf "\x1B[32m\033[3mSucces\033[0m!\n"
            if [[ -n $where ]]; then
                ln -s "${plugindir}" "${PLUGROOT}/${github_name}"
            fi
        else
            printf "\r\x1B[31mFAILED\033[0m to install \x1B[35m\033[3m$pluginname\033[0m, skipping…\n"
            return 1
        fi


        if [[ -n ${postinstall_hook} ]]; then
            printf "\rRunning post-install hooks for \x1B[35m\033[3m${(r:19:)pluginname##*/}\033[0m … " &&\
            eval "${postinstall_hook}" &&\
            printf "\x1B[32m\033[3mSucces\033[0m!\n" ||\
            printf "\r\x1B[31mFailed to run post-install hooks for \x1B[35m\033[3m$pluginname\033[0m\n"
        fi
    fi
}

sourcer() {
    local __ignorelevel="$1" __filename="$2" __plugindir="$3" __postload_hook="$4"

    if [[ ! ${__ignorelevel} == 'ignore' ]]; then

        local __file_to_source
        # we determine what file to source.
        if [[ -n $__filename ]]; then
            __file_to_source="${__plugindir}/${__filename##*/}"
        else
            __file_to_source="${__plugindir}/${github_name##*/}.plugin.zsh"
            if [[ ! -f "${__file_to_source}" ]]; then
                __file_to_source="${__plugindir}/${${github_name##*/}//.zsh/}.zsh"
            fi
        fi

        if [ ! -f "${__file_to_source}" ]; then
            printf "No file with the name \"${__file_to_source##*/}\"\n"
            printf "No file with the name \"${__file_to_source}\"\n"
            return 1
        fi

        if [[ "${__file_to_source##*.}" == "zsh" ]]; then
            files_to_compile+="${__file_to_source}"
        fi

        if [[ ! "${__ignorelevel}" == 'nosource' ]]; then
            source "$__file_to_source"
        fi
    fi

    if [[ -n "${__postload_hook}" ]]; then
        eval "${__postload_hook}"
    fi
}

updater() {
    local plugin="$1" __plugindir="$2"
    printf "Updating \x1B[35m\033[3m${(r:40:: :)plugin} "
    printf "\033[0m … \x1B[32m"

    if git -C ${__plugindir} pull 2> /dev/null; then
        printf "\033[0m"
    else
        printf "\x1B[31mFailed to update\033[0m\n"
        return 1
    fi
}

plug trobjo/zsh-plugin-manager, ignorelevel:nosource

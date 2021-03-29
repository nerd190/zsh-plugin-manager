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
declare -aU __files_to_compile=("${ZDOTDIR:-$HOME}/.zshrc" "${ZDOTDIR:-$HOME}/.zcompdump")

export PLUGROOT="${ZDOTDIR}/plugins"

plug() {
    local myarr=($@)
    set --
    case "${myarr[1]}" in
        (init)
        if [[ -n ${__asynchronous_plugins} ]]; then
            plug romkatv/zsh-defer
            __plug init ${__synchronous_plugins}
            zsh-defer -1 __plug init ${__asynchronous_plugins}
        elif [[ -n ${__synchronous_plugins} ]]; then
            __plug init ${__synchronous_plugins}
        fi
        compile_or_recompile ${__files_to_compile}
        ;;
        (update)
        if [[ ${#myarr[@]} -gt 1 ]]; then
            shift
            for plugin in "$@"; do
                echo $plugin
                echo ${__synchronous_plugins}
                if (( ${__synchronous_plugins[(r)plugin*]} )); then
                    echo "it's in"
                else
                    echo "it's somewhere else maybe"
                fi
            done

        else
            __plug update ${__synchronous_plugins} ${__asynchronous_plugins}
        fi
        compile_or_recompile ${__files_to_compile}
        ;;
        (install)
        echo to come
        if [[ ${#myarr[@]} -gt 1  ]]; then
            printf "\r\x1B[31mCannot install plugins interactively, please load from .zshrc\033[0m\n"
        fi
        ;;
        (async)
        __asynchronous_plugins+="${${myarr//,[[:blank:]]/│}:6}"
        ;;
        (*)
        if [[ "${myarr}" != *"/"* ]]; then
            printf "\r\x1B[3m${myarr}\033[0m does not look like a plugin and is not an action\033[0m\n"
            return 1
        fi
        __synchronous_plugins+="${myarr//,[[:blank:]]/│}"
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
        unset ignorelevel filename plugin_dir_local_location postload_hook github_name postinstall_hook where file_to_source
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
                printf "\r\x1B[31mDid not understand the key: \033[0m\x1B[3m"${part}"\033[0m\nSkipping \x1B[35m"${github_name}"\033[0m plugin\n"
                continue 2
                ;;
            esac
        done


        if [ -z $where ]; then
            plugin_dir_local_location="${PLUGROOT}/$github_name"
        else
            plugin_dir_local_location=${where}
        fi

        local action="${myarr[1]}"
        if [[ $action == 'update' ]]; then

            printf "Updating \x1B[35m\033[3m${(r:40:: :)github_name} "
            printf "\033[0m … \x1B[32m"

            if git -C ${plugin_dir_local_location} pull 2> /dev/null; then
                printf "\033[0m"
            else
                printf "\x1B[31mFailed to update\033[0m\n"
                continue
            fi

        elif [[ $action == 'init' ]]; then
            if [[ ! -d "${plugin_dir_local_location}" ]]; then
                printf "\rInstalling \x1B[35m\033[3m${(r:39:)github_name}\033[0m … "

                if git clone --depth=1 "https://github.com/${github_name}.git" ${plugin_dir_local_location} 2> /dev/null; then
                    printf "\x1B[32m\033[3mSucces\033[0m!\n"
                    if [[ -n $where ]]; then
                        ln -s "${plugin_dir_local_location}" "${PLUGROOT}/${github_name}"
                    fi
                else
                    printf "\r\x1B[31mFAILED\033[0m to install \x1B[35m\033[3m$github_name\033[0m, skipping…\n"
                    printf "Backtrace:\n"
                    printf "plugin_dir_local_location: \x1B[32m${plugin_dir_local_location}\033[0m\n"
                    printf "github_name: \x1B[32m${github_name}\033[0m\n"
                    continue
                fi

                if [[ -n ${postinstall_hook} ]]; then
                    printf "\rRunning post-install hooks for \x1B[35m\033[3m${(r:19:)github_name##*/}\033[0m … " &&\
                    eval "${postinstall_hook}" &&\
                    printf "\x1B[32m\033[3mSucces\033[0m!\n" ||\
                    printf "\r\x1B[31mFailed to run post-install hooks for \x1B[35m\033[3m$github_name\033[0m\n"
                fi
            fi
        fi

        if [[ ! ${ignorelevel} == 'ignore' ]]; then

            # we determine what file to source.
            if [[ -n $filename ]]; then
                file_to_source="${plugin_dir_local_location}/${filename}"
            else
                file_to_source="${plugin_dir_local_location}/${github_name##*/}.plugin.zsh"
                if [[ ! -f "${file_to_source}" ]]; then
                    file_to_source="${plugin_dir_local_location}/${${github_name##*/}//.zsh/}.zsh"
                fi
            fi

            if [ ! -f "${file_to_source}" ]; then
                printf "No file with the name \"${file_to_source}\"\n"
                continue
            fi

            __files_to_compile+="${file_to_source}"

            if [[ ! "${ignorelevel}" == 'nosource' ]]; then
                source "$file_to_source"
            fi
        fi

        if [[ -n "${postload_hook}" ]]; then
            eval "${postload_hook}"
        fi
    done
    unset ignorelevel filename plugin_dir_local_location postload_hook github_name postinstall_hook where file_to_source
}

plug trobjo/zsh-plugin-manager, ignorelevel:nosource

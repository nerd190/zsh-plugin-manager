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

export PLUGROOT="${ZDOTDIR}/plugins"

plug() {
    local args=($@)
    set --
    case "${args[1]}" in
        (init)
        __synchronous_plugins+=${__asynchronous_plugins:+romkatv/zsh-defer}
        if [[ ! -d "${PLUGROOT}/romkatv/zsh-defer" ]]; then
            __plug init ${__synchronous_plugins} ${__asynchronous_plugins}
        else
            __plug init ${__synchronous_plugins}
            [[ -n ${__asynchronous_plugins} ]] && zsh-defer -12ms __plug init ${__asynchronous_plugins}
        fi
        ;;
        (remove)
        for plugin in "${args[@]:1}"; do
            rm -rf $(readlink -f "$PLUGROOT/${plugin}") "$PLUGROOT/${plugin}"
        done
        ;;
        (update)
        if [[ ${args[2]} == '--force' ]]; then
            force=true
        fi
        # elif [[ ${#args[@]} -gt 1 ]]; then
        #     for plugin in "$args[@]"; do
        #         echo $plugin
        #         echo ${__synchronous_plugins}
        #         if (( ${__synchronous_plugins[(r)plugin*]} )); then
        #             echo "it's in"
        #         else
        #             echo "it's somewhere else maybe"
        #         fi
        #     done

        # else
        __plug update trobjo/zsh-plugin-manager ${__synchronous_plugins} ${__asynchronous_plugins}
        # fi
        ;;
        (async)
        __asynchronous_plugins+="${args:6}"
        ;;
        (*)
        if [[ "${args}" != *"/"* ]]; then
            printf "\r\x1B[3m${args}\033[0m does not look like a plugin and is not an action\033[0m\n"
            return 1
        fi
        __synchronous_plugins+="${args}"
        ;;
    esac
}

compile_or_recompile() {
    if [[ -f "${1}" ]] && [[ ! -f "${1}.zwc" ]] \
        || [[ "${1}" -nt "${1}.zwc" ]]; then
            zcompile "$1"
    fi
}

    __plug() {
        local pluglist=($@)
        set --

        local action="${pluglist[1]}"
        local plugin
        for plugin in "${pluglist[@]:1}"; do
            unset ignorelevel filename plugin_dir_local_location postload github_name postinstall where files fetchcommand
            declare -aU files
        # split strings by args
        parts=("${(@s[, ])plugin}")
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
                (postinstall)
                local postinstall="${value}"
                ;;
                (postload)
                local postload="${value}"
                ;;
                (env)
                export "${(e)value}"
                ;;
                (where)
                local where="${(e)value}"
                ;;
                (source)
                filename+=("${(e)value}")
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

        if [[ $action == 'update' ]]; then
            printf "Updating \x1B[35m\033[3m${(r:40:: :)github_name} \033[0m … "
            if git -C ${plugin_dir_local_location} pull 2> /dev/null; then
                printf "\033[0m"
            elif [[ -n $force ]]; then
                git -C ${plugin_dir_local_location} reset --hard HEAD
                git -C ${plugin_dir_local_location} pull 2> /dev/null
            else
                printf "\x1B[31mFailed to update\033[0m\n"
                continue
            fi
        elif [[ $action == 'init' ]]; then
            if [[ ! -e "${plugin_dir_local_location}" ]]; then
                printf "\rInstalling \x1B[35m\033[3m${(r:39:)github_name}\033[0m … "

                prefix="${github_name:0:4}"
                if [[ "$prefix" == 'http' ]]; then
                    filename=("${github_name##*/}")
                    fetchcommand='curl -L -O "$github_name"'
                elif [[ "$prefix" == 'git@' ]]; then
                    fetchcommand='git clone --depth=1 "$github_name" ${plugin_dir_local_location}'
                else
                    # we assume github
                    fetchcommand='git clone --depth=1 "https://github.com/${github_name}.git" ${plugin_dir_local_location}'
                fi

                if eval "${fetchcommand}" 2> /dev/null; then
                    printf "\x1B[32m\033[3mSucces\033[0m!\n"
                    if [[ -n $where ]]; then
                        if [[ $prefix == "http" ]]; then
                            ln -s "${plugin_dir_local_location}" "${PLUGROOT}/${plugin_dir_local_location##*/}"
                        else
                            ln -s "${plugin_dir_local_location}" "${PLUGROOT}/$github_name"
                        fi
                    fi
                else
                    printf "\r\x1B[31mFAILED\033[0m to install \x1B[35m\033[3m$github_name\033[0m, skipping…\n"
                    printf "Backtrace:\n"
                    printf "plugin_dir_local_location: \x1B[32m${plugin_dir_local_location}\033[0m\n"
                    printf "github_name: \x1B[32m${github_name}\033[0m\n"
                    continue
                fi

                if [[ -n ${postinstall} ]]; then
                    maxlength=${${github_name##*/}:0:21}
                    printf "\rPerforming \x1B[35m\033[3m${maxlength}\033[0m post-install hook "
                    printf %$((21 - ${#maxlength}))s…
                    eval "${postinstall}" 1> /dev/null &&\
                    printf " \x1B[32m\033[3mSucces\033[0m!\n" ||\
                    printf "\r\x1B[31mFailed to run install hook for \x1B[35m\033[3m$github_name\033[0m\n"
                fi
            fi
        fi

        if [[ ! ${ignorelevel} == 'ignore' ]]; then
            # we determine what filename to source.
            if [[ -n $filename ]]; then
                for file in "$filename[@]"; do
                    files+=("${plugin_dir_local_location}/${file}")
                done
            else
                files=("${plugin_dir_local_location}/${${github_name##*/}//.zsh/}.zsh")
                if [[ ! -f "${files[1]}" ]]; then
                    files=("${plugin_dir_local_location}/${github_name##*/}.plugin.zsh")
                fi
            fi

            for file in "$files[@]"; do
                if [ ! -f "${file}" ]; then
                    printf "No file with the name \"${file}\"\n"
                else
                    compile_or_recompile "${file}"
                    source "$file"
                fi
            done
        fi

        if [[ -n "${postload}" ]]; then
            eval "${(e)postload}"
        fi
    done
    unset ignorelevel filename plugin_dir_local_location postload github_name postinstall where files fetchcommand force
}

compile_or_recompile "${ZDOTDIR:-$HOME}/.zshrc"
compile_or_recompile "${ZDOTDIR:-$HOME}/.zcompdump"
compile_or_recompile "$0"

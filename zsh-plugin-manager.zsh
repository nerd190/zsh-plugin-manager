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
# The fourth field contains post-install hooks.


compile_or_recompile() {
  local file
  for file in "$@"; do
    if [[ -f $file ]] && [[ ! -f ${file}.zwc ]] \
      || [[ $file -nt ${file}.zwc ]]; then
          zcompile "$file"
      fi
  done
}

local -aU files_to_compile=("${ZDOTDIR:-$HOME}/.zshrc" "${ZDOTDIR:-$HOME}/.zcompdump")



plugin_manager() {
    local myarr=($@)
    set --

    # we construct an array if only 1 arg is given.
    if [[ ${#myarr[@]} -eq 1 ]]; then
        myarr+=($synchronous_plugins $asynchronous_plugins)
    fi

    local action="${myarr[1]}"
    if [[ ${action} != "install" ]] && [[ ${action} != "update" ]]; then
        printf "\r\x1B[31mDid not understand action \x1B[35m\033[3m${action}\033[0m\n"
        return 1
    fi

    local plugin
    for plugin in "${myarr[@]:1}"; do

        # split strings by args
        parts=("${(@s[│])plugin}")
        local __plugin="${parts[1]}"

        for part in "${parts[@]:1}"; do

            key="${part%%:*}"
            value="${part#*:}"
            case "${key}" in
                (if)
                    eval "${value}" > /dev/null 2>&1 || break 2
                    ;;
                (ignorelevel)
                    local ignorelevel="${value}"
                    ;;
                (postinstall_hook)
                    local postinstall_hook="${value}"
                    ;;
                (postload_hook)
                    local postload_hook="${value}"
                    ;;
                (env)
                    export "${value}"
                    ;;
                (filename)
                    local filename="${value}"
                    ;;
                (*)
                    printf "\n\x1B[31mDid not understand \033[0m\""${part}"\"\nSkipping \x1B[35m"${parts[1]}"\033[0m plugin\n"
                    continue
                    ;;
            esac
        done


        if [ -z $plugindir ]; then
            plugindir="${ZDOTDIR}/plugins/$__plugin"
        fi

        if [[ $action == 'update' ]]; then
            printf "Updating \x1B[35m\033[3m${(r:40:: :)parts[1]} "
            printf "\033[0m … \x1B[32m"
            git -C ${plugindir} pull &&\
            printf "\033[0m" ||\
            printf "\r\x1B[31mFailed to install \x1B[35m\033[3m$__plugin\033[0m\n"
        elif [[ $action == 'install' ]]; then

            if [[ ! -d $plugindir ]]; then

                printf "\rInstalling \x1B[35m\033[3m${(r:39:)parts[1]}\033[0m … " &&\
                git clone https://github.com/$__plugin.git ${plugindir} 2> /dev/null &&\
                echo ${plugindir} >> ${ZDOTDIR}/plugins/count
                printf "\x1B[32m\033[3mSucces\033[0m!\n" ||\
                printf "\r\x1B[31mFailed to install \x1B[35m\033[3m$__plugin\033[0m\n"

                if [[ -n ${postinstall_hook} ]]; then
                    printf "\rRunning post-install hooks for \x1B[35m\033[3m${(r:19:)parts[1]##*/}\033[0m … " &&\
                    eval "${postinstall_hook}" &&\
                    printf "\x1B[32m\033[3mSucces\033[0m!\n" ||\
                    printf "\r\x1B[31mFailed to run post-install hooks for \x1B[35m\033[3m$__plugin\033[0m\n"
                    unset postinstall_hook
                fi
            fi
        fi


        if [[ ! ${ignorelevel} == 'ignore' ]]; then

            # we determine what file to source.
            if [[ -n $filename ]]; then
                pluginfile="${plugindir}/${filename##*/}"
            else
                pluginfile="${plugindir}/${parts[1]##*/}.plugin.zsh"
                if [[ ! -f "${pluginfile}" ]]; then
                    pluginfile="${plugindir}/${${parts[1]##*/}//.zsh/}.zsh"
                fi
            fi

            if [ ! -f "${pluginfile}" ]; then
                printf "No file with the name \"${pluginfile##*/}\"\n"
                printf "No file with the name \"${pluginfile}\"\n"
                continue
            fi

            if [[ "${pluginfile##*.}" == "zsh" ]]; then
                files_to_compile+="${pluginfile}"
            fi

            if [[ ! ${ignorelevel} == 'nosource' ]]; then
                source "$pluginfile"
                # printf "sourced $pluginfile\n"
            fi

        fi


        if [[ -n "${postload_hook}" ]]; then
            eval "${postload_hook}"
            unset postload_hook
        fi

        unset ignorelevel postinstall_hook filename plugindir pluginfile

    done
    compile_or_recompile ${files_to_compile}
    unset files_to_compile
}



#
## PLUGIN MANAGER
#

# plugin_manager documentation:
# arguments can be passed to plugin_manager separated by '│'.
# The second field is the name of the file to source if it is
# named differently than the plugin. The third field may contain
# a command that must return exit code 0 for the plugin to load.
# For example, you can avoid loading plugins if dependencies are
# not found in $PATH.
# The fourth field contains post-install hooks.


find_plugin_dir() {

}



plugin_manager() {
    local myarr=($@)
    set --

    if [[ "${myarr[1]}" == "remove" ]]; then

        myarr=(${synchronous_plugins} ${asynchronous_plugins})
        # local filelist=($(cd ${ZDOTDIR}/plugins; find * -type d -path '*/*' -prune -print))
        local filelist=($(cat ${ZDOTDIR}/plugins/count))

        local parts
        local dir
        local plugindir
        for plug in "${myarr[@]}"; do
            parts=("${(@s[│])plug}")
            dir="${ZDOTDIR}/plugins/${parts[1]}"
            if [[ ! -z ${parts[3]} ]]; then
                eval "${parts[3]}" > /dev/null 2>&1 || continue
                if [[ ! -z "${plugindir}" ]]; then
                    dir="${plugindir}"
                fi
            fi
            filelist=(${filelist[@]//*${dir}*})
        done

        for elem in "${filelist[@]}"; do
            sed -i -r -e "/${elem//\//\\/}/d" ${ZDOTDIR}/plugins/count
            rm -rf "${elem}"
            printf "Removed \x1B[31m\033[3m${elem}\033[0m …\n"
        done

        printf "Removed \x1B[31m\033[1m${#filelist}\033[0m elements\n"
        return
    fi

    # we construct an array if only 1 arg is given.
    # to be run interactively
    if [[ ${#myarr[@]} -eq 1 ]]; then
        myarr+=($synchronous_plugins $asynchronous_plugins)
    fi

    local plugin
    for plugin in "${myarr[@]:1}"; do
        # split strings by args
        parts=("${(@s[│])plugin}")
        local __plugin="${parts[1]}" __altname="${parts[2]}" __evaluate="${parts[3]}" __ignorelevel="${parts[4]}" __postinstall_hook="${parts[5]}" __post_load_hook="${parts[6]}"

        if [[ ! -z ${__evaluate} ]]; then
            eval "${__evaluate}" > /dev/null 2>&1 || continue
        fi

        if [ -z $plugindir ]; then
            plugindir="${ZDOTDIR}/plugins/$__plugin"
        fi

        case "${myarr[1]}" in
            (update|pull)
                printf "Updating \x1B[35m\033[3m${(r:40:: :)parts[1]} "
                printf "\033[0m … \x1B[32m"
                git -C ${plugindir} pull &&\
                printf "\033[0m" ||\
                printf "\r\x1B[31mFailed to install \x1B[35m\033[3m$__plugin\033[0m\n"
                ;;
            (install|load)
                if [[ ! -d $plugindir ]]; then
                    printf "\rInstalling \x1B[35m\033[3m${(r:39:)parts[1]}\033[0m … " &&\
                    git clone https://github.com/$__plugin.git ${plugindir} 2> /dev/null &&\
                    echo ${plugindir} >> ${ZDOTDIR}/plugins/count
                    printf "\x1B[32m\033[3mSucces\033[0m!\n" ||\
                    printf "\r\x1B[31mFailed to install \x1B[35m\033[3m$__plugin\033[0m\n"
                    if [[ ! -z ${__postinstall_hook} ]]; then
                        printf "\rRunning post-install hooks for \x1B[35m\033[3m${(r:19:)parts[1]##*/}\033[0m … " &&\
                        eval "${__postinstall_hook}" &&\
                        printf "\x1B[32m\033[3mSucces\033[0m!\n" ||\
                        printf "\r\x1B[31mFailed to run post-install hooks for \x1B[35m\033[3m$__plugin\033[0m\n"
                    fi
                fi
                ;;
            (*)
            ;;
        esac

        if [[ ! ${__ignorelevel} == 'ignore' ]]; then

            # we determine what file to source.
            if [[ ! -z $__altname ]]; then
                pluginfile="${plugindir}/${__altname##*/}"
            else
                pluginfile="${plugindir}/${parts[1]##*/}.plugin.zsh"
                if [[ ! -f "${pluginfile}" ]]; then
                    pluginfile="${plugindir}/${${parts[1]##*/}//.zsh/}.zsh"
                fi
            fi

            if [ ! -f "${pluginfile}" ]; then
                printf "No file with the name \"${pluginfile##*/}\"\n"
                continue
            fi

            if [[ "${pluginfile##*.}" == "zsh" ]]; then
                compile_or_recompile "$pluginfile"
            fi

            if [[ ! ${__ignorelevel} == 'nosource' ]]; then
                source "$pluginfile"
            fi
        fi

        # post load hooks
        if [[ ! -z ${__post_load_hook} ]]; then
            eval "${__post_load_hook}"
        fi

        unset pluginfile
        unset plugindir

    done
}

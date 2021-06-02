typeset -aU _plugins
typeset -aU _installed_plugins
export PLUGROOT="${ZDOTDIR}/plugins"

plug() {
    case "${@[1]}" in
        (init)
            __plug_init
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
        _plugins=("trobjo/zsh-plugin-manager" "$_plugins[@]")
        __plug_update
        unset force
        ;;
        (*)
        if [[ -z $DEFER_LOADED ]] && (($@[(I)defer*])); then
            _plugins=("romkatv/zsh-defer" "$_plugins[@]")
            DEFER_LOADED=true
        fi
        _plugins+="$@"
        ;;
    esac
}

compile_or_recompile() {
    if [[ -f "${1}" ]] && [[ ! -f "${1}.zwc" ]] \
        || [[ "${1}" -nt "${1}.zwc" ]]; then
            zcompile "$1"
        fi
}

__plug_update() {
    set --
    local plugin
    for plugin in ${_plugins}; do
    unset where plugindir github_name
    parts=("${(@s[, ])plugin}")
    local github_name="${parts[1]}"
    for part in "${parts[@]:1}"; do
        key="${part%%:*}"
        value="${part#*:}"
        case "${key}" in
            (if)
            eval "${value}" > /dev/null 2>&1 || continue 2
            ;;
            (where)
            [[ -d $value ]] || continue 2
            local where="${(e)value}"
            ;;
            (*)
            ;;
            esac
        done

        plugindir="${where:-${PLUGROOT}/$github_name}"

        printf "Updating \x1B[35m\033[3m${(r:40:: :)github_name} \033[0m … "
        if git -C ${plugindir} pull 2> /dev/null; then
            continue
        elif [[ -n $force ]]; then
            git -C ${plugindir} reset --hard HEAD
            git -C ${plugindir} pull 2> /dev/null
        else
            printf "\x1B[31mFailed to update\033[0m\n"
            continue 1
        fi
    done
    printf "\x1B[32mIf plugins were updated, you should restart your shell\033[0m\n"
}

__plug_init() {
    printf "\x1b[?25l"            # hide the cursor while we update
    set --
    local plugin
    for plugin in ${_plugins}; do
        unset source_cmd github_name filename plugindir preload postload postinstall where fetchcommand
        # split strings by args
        parts=("${(@s[, ])plugin}")
        github_name="${parts[1]}"

        for part in "${parts[@]:1}"; do
            key="${part%%:*}"
            value="${part#*:}"
            case "${key}" in
                (if)
                eval "${value}" > /dev/null 2>&1 || continue 2
                ;;
                (preload|postload|postinstall)
                local $key="${${(P)key}:+${(P)key}; }${value}"
                ;;
                (defer)
                source_cmd=("zsh-defer" "${value/defer/}")
                ;;
                (ignore)
                source_cmd="ignore"
                ;;
                (where)
                where="${(e)value}"
                ;;
                (*)
                printf "\r\x1B[31mDid not understand the key: \033[0m\x1B[3m"${part}"\033[0m\nSkipping \x1B[35m"${github_name}"\033[0m plugin\n"
                continue 2
                ;;
            esac
        done

        plugindir="${where:-${PLUGROOT}/$github_name}"

        if [[ ! -e "${plugindir}" ]]; then
            printf "\rInstalling \x1B[35m\033[3m${(r:39:)github_name}\033[0m … "

            prefix="${github_name:0:4}"
            case "${github_name:0:4}" in
                http)
                    filename=("${github_name##*/}")
                    if [[ "${filename:e}" == "" ]]; then
                        fetchcommand=("curl" "-L" "$github_name" "--create-dirs" "--output" "$where")
                    else
                        fetchcommand=("curl" "-L" "-O" "$github_name")
                    fi
                    ;;
                git@)
                    fetchcommand=("git" "clone" "--depth=1" "$github_name" "${plugindir}")
                    ;;
                *)
                    fetchcommand=("git" "clone" "--depth=1" "https://github.com/${github_name}.git" "${plugindir}")
                    ;;
            esac

            if ${fetchcommand} 2> /dev/null; then
                printf "\x1B[32m\033[3mSucces\033[0m!\n"
                if [[ "${filename:e}" == "gz" ]]; then
                    tar zxvf "${filename}" --directory "${where%/*}/" 1> /dev/null
                    rm "${filename}"
                    chmod +x "$where"
                elif [[ -n ${postinstall} ]]; then
                    eval "${(e)postinstall}" 1> /dev/null ||\
                    printf "\r\x1B[31mFailed to run postinstall hook for \x1B[35m\033[3m$github_name\033[0m\n"
                fi
            else
                printf "\r\x1B[31mFAILED\033[0m to install \x1B[35m\033[3m$github_name\033[0m, skipping…\n"
                continue
            fi
        fi

        if [[ -n "${preload}" ]]; then
            eval "${(e)preload}"
        fi

        if [[ ${source_cmd} != "ignore" ]]; then
            filename="${plugindir}/${${github_name##*/}//.zsh/}.zsh"
            if [[ ! -f "${filename}" ]]; then
                filename="${plugindir}/${github_name##*/}.plugin.zsh"
                if [[ ! -f "${filename}" ]]; then
                    filename="${plugindir}/${${github_name##*/}//zsh-/}.plugin.zsh"
                    if [ ! -f "${filename}" ]; then
                        printf "No filename with the name \"${filename}\"\n"
                        continue
                    fi
                fi
            fi
            compile_or_recompile "${filename}"
            ${source_cmd} source "$filename"
        fi

        if [[ -n "${postload}" ]]; then
            eval "${(e)postload}"
        fi

        _installed_plugins+=("\n${remote_location}")

    done
    unset github_name filename plugindir preload postload postinstall where fetchcommand source_cmd
    printf "\x1b[?25h"            # show the cursor again
}

compile_or_recompile "${ZDOTDIR:-$HOME}/.zshrc"
compile_or_recompile "${ZDOTDIR:-$HOME}/.zcompdump"
compile_or_recompile "$0"

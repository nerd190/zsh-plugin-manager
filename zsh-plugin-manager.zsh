declare -aU __synchronous_plugins
declare -aU __asynchronous_plugins

export PLUGROOT="${ZDOTDIR}/plugins"

plug() {
    case "${@[1]}" in
        (init)
        __synchronous_plugins+=${__asynchronous_plugins:+romkatv/zsh-defer}
        __plug_init __synchronous_plugins
        [[ -n ${__asynchronous_plugins} ]] && __plug_init __asynchronous_plugins
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
        __plug_update trobjo/zsh-plugin-manager ${__synchronous_plugins} ${__asynchronous_plugins}
        unset force
        ;;
        (async)
        shift
        __asynchronous_plugins+="$@"
        ;;
        (*)
        if [[ "${@[1]}" != *"/"* ]]; then
            printf "\r\x1B[3m$@\033[0m does not look like a plugin and is not an action\033[0m\n"
            return 1
        fi
        __synchronous_plugins+="$@"
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
    local pluglist=($@)
    set --
    local plugin
    for plugin in "${pluglist[@]}"; do
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
    [[ $1 == __asynchronous_plugins ]] && source_cmd=("zsh-defer")
    source_cmd+="source"
    local input=${1}
    set --
    for plugin in ${${(P)input}}; do
        unset nosource github_name filename plugindir preload postload postinstall where fetchcommand
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
                (nosource)
                if [[ "${${value}:l}" == "true" ]] || [[ "${value}" -eq 1 ]]; then
                    nosource=true
                fi
                ;;
                (postinstall)
                postinstall="${postinstall:+$postinstall; }${value}"
                ;;
                (preload)
                preload="${preload:+$preload; }${value}"
                ;;
                (postload)
                postload="${postload:+$postload; }${value}"
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
            if [[ "$prefix" == 'http' ]]; then
                filename=("${github_name##*/}")
                fetchcommand='curl -L -O "$github_name"'
            elif [[ "$prefix" == 'git@' ]]; then
                fetchcommand='git clone --depth=1 "$github_name" ${plugindir}'
            else
                # we assume github
                fetchcommand='git clone --depth=1 "https://github.com/${github_name}.git" ${plugindir}'
            fi

            if eval "${fetchcommand}" 2> /dev/null; then
                printf "\x1B[32m\033[3mSucces\033[0m!\n"
            if [[ -n $where ]]; then
                if [[ $prefix == "http" ]]; then
                    ln -s "${plugindir}" "${PLUGROOT}/${plugindir##*/}"
                else
                    ln -s "${plugindir}" "${PLUGROOT}/$github_name"
                    fi
                fi
            else
                printf "\r\x1B[31mFAILED\033[0m to install \x1B[35m\033[3m$github_name\033[0m, skipping…\n"
                printf "Backtrace:\n"
                printf "plugindir: \x1B[32m${plugindir}\033[0m\n"
                printf "github_name: \x1B[32m${github_name}\033[0m\n"
                continue
            fi

            if [[ -n ${postinstall} ]]; then
            maxlength=${${github_name##*/}:0:21}
            printf "\rPerforming \x1B[34m\033[3m${maxlength}\033[0m post-install hook "
            printf %$((21 - ${#maxlength}))s…
            eval "${(e)postinstall}" 1> /dev/null &&\
            printf " \x1B[32m\033[3mSucces\033[0m!\n" ||\
            printf "\r\x1B[31mFailed to run postinstall hook for \x1B[35m\033[3m$github_name\033[0m\n"
            fi
        fi

        if [[ -n "${preload}" ]]; then
            eval "${(e)preload}"
        fi

        if [[ -z ${nosource} ]]; then
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
            ${source_cmd} "$filename"
        fi

        if [[ -n "${postload}" ]]; then
            eval "${(e)postload}"
        fi
    done
    unset nosource github_name filename plugindir preload postload postinstall where fetchcommand
    printf "\x1b[?25h"            # show the cursor again
}

compile_or_recompile "${ZDOTDIR:-$HOME}/.zshrc"
compile_or_recompile "${ZDOTDIR:-$HOME}/.zcompdump"
compile_or_recompile "$0"

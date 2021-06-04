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
    unset where plugin_location remote_location
    parts=("${(@s[, ])plugin}")
    local remote_location="${parts[1]}"
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

        plugin_location="${where:-${PLUGROOT}/$remote_location}"

        printf "Updating \x1B[35m\033[3m${(r:40:: :)remote_location} \033[0m … "
        if git -C ${plugin_location} pull 2> /dev/null; then
            continue
        elif [[ -n $force ]]; then
            git -C ${plugin_location} reset --hard HEAD
            git -C ${plugin_location} pull 2> /dev/null
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
        unset source_cmd remote_location filename plugin_location preload postload postinstall where fetchcommand pwd
        # split strings by args
        parts=("${(@s[, ])plugin}")
        remote_location="${parts[1]}"

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
                printf "\r\x1B[31mDid not understand the key: \033[0m\x1B[3m"${part}"\033[0m\nSkipping \x1B[35m"${remote_location}"\033[0m plugin\n"
                continue 2
                ;;
            esac
        done

        plugin_location="${where:-${PLUGROOT}/$remote_location}"

        if [[ ! -e "${plugin_location}" ]]; then
            printf "\rInstalling \x1B[35m\033[3m${(r:39:)remote_location}\033[0m … "

            if [[ "$remote_location" =~ ^[-a-zA-Z_0-9]+/[-\.a-zA-Z_0-9]+$ ]]; then
                git clone --depth=1 "https://github.com/${remote_location}.git" "${plugin_location}" 2> /dev/null
            elif ! git clone --depth=1 "$remote_location" "${plugin_location}" 2> /dev/null; then
                filename=("${PWD}/${remote_location##*/}")
                curl -L "$remote_location" --output "$filename"
                if [[ "${filename:e}" == "" ]]; then
                    mv "${filename}" "${where}" && chmod +x "${where}" && success=1
                else
                    mkdir "tmp"
                    cd tmp

                    case "${filename:l}" in
                        (*.tar.gz|*.tgz) (( $+commands[pigz] )) && { pigz -dc "$filename" | tar xv } || tar zxvf "$filename" ;;
                        (*.tar.bz2|*.tbz|*.tbz2) tar xvjf "$filename" ;;
                        (*.tar.xz|*.txz)
                            tar --xz --help &> /dev/null \
                            && tar --xz -xvf "$filename" \
                            || xzcat "$filename" | tar xvf - ;;
                        (*.tar.zma|*.tlz)
                            tar --lzma --help &> /dev/null \
                            && tar --lzma -xvf "$filename" \
                            || lzcat "$filename" | tar xvf - ;;
                        (*.tar.zst|*.tzst)
                            tar --zstd --help &> /dev/null \
                            && tar --zstd -xvf "$filename" \
                            || zstdcat "$filename" | tar xvf - ;;
                        (*.tar) tar xvf "$filename" ;;
                        (tar.lz) (( $+commands[lzip] )) && tar xvf "$filename" ;;
                        (*.gz) (( $+commands[pigz] )) && pigz -dk "$filename" || gunzip -k "$filename" ;;
                        (*.bz2) bunzip2 "$filename" ;;
                        (*.xz) unxz "$filename" ;;
                        (*.lzma) unlzma "$filename" ;;
                        (*.z) uncompress "$filename" ;;
                        (*.zip|*.war|*.jar|*.sublime-package|*.ipsw|*.xpi|*.apk|*.aar|*.whl) unzip "$filename" ;;
                        (*.rar) unrar x -ad "$filename" ;;
                        (*.7z) 7za x "$filename" ;;
                        (*.zst) unzstd "$filename" ;;
                        (*)
                            print "Wrong file type: '$filename' "
                            rmdir "$where"
                            continue
                        ;;
                    esac
                    all_files=(*(ND))

                    if [[ ${#all_files[@]} -eq 1 ]] && [[ -f "${all_files}" ]]; then
                        mv "${all_files}" "${plugin_location}"
                        cd ..
                        rmdir tmp
                    else
                        if [[ ${#all_files[@]} -eq 1 ]] && [[ -d "${all_files}" ]]; then
                            mv "${all_files}/"*(D) . && rmdir "${all_files}"
                        fi
                        cd ..
                        mv tmp "${plugin_location}"
                    fi
                fi
            fi

            if [[ $? == 0 ]]; then
                printf "\x1B[32m\033[3mSucces\033[0m!\n"
                if [[ -n ${postinstall} ]]; then
                    eval "${(e)postinstall}" 1> /dev/null ||\
                    printf "\r\x1B[31mFailed to run postinstall hook for \x1B[35m\033[3m$remote_location\033[0m\n"
                fi
            else
                printf "\r\x1B[31mFAILED\033[0m to install \x1B[35m\033[3m$remote_location\033[0m, skipping…\n"
                continue
            fi
        fi

        if [[ -n "${preload}" ]]; then
            eval "${(e)preload}"
        fi

        if [[ ${source_cmd} != "ignore" ]]; then
            filename="${plugin_location}/${${remote_location##*/}//.zsh/}.zsh"
            if [[ ! -f "${filename}" ]]; then
                filename="${plugin_location}/${remote_location##*/}.plugin.zsh"
                if [[ ! -f "${filename}" ]]; then
                    filename="${plugin_location}/${${remote_location##*/}//zsh-/}.plugin.zsh"
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

        _installed_plugins+=("\n${where:-$remote_location}")

    done
    unset remote_location filename plugin_location preload postload postinstall where fetchcommand source_cmd
    printf "\x1b[?25h"            # show the cursor again
}

compile_or_recompile "${ZDOTDIR:-$HOME}/.zshrc"
compile_or_recompile "${ZDOTDIR:-$HOME}/.zcompdump"
compile_or_recompile "$0"

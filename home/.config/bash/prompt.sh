# Bash prompt and colors, matching alacritty.toml's palette (the colors are the terminal's ANSI
# indexes, so they follow the theme). Loaded from ~/.bashrc (install.sh adds it):
#   [[ -f ~/.config/bash/prompt.sh ]] && . ~/.config/bash/prompt.sh
#
#    ~/…/quickshell/scripts   main ⇡1 +2 ~1 ?3   ✘ 1
#   ❯
# - The directory, with ~ for $HOME and, if long, shortened to the first folder + the last 3.
#   Parent folders in muted coral and the current one in bright bold coral.
# - The git branch (or the commit, if detached), in magenta, with commits to push (⇡) or pull (⇣),
#   staged changes (+, green), unstaged (~, yellow), conflicts (!, red) and untracked
#   files (?, grey).
# - Active Python environment, background jobs and the exit code if the last command
#   failed. user@host only over SSH or as root (root in red).
# - The ❯ arrow is green if the last command succeeded and red if it failed.

[[ $- == *i* ]] || return

# --- Program colors ---
# ls: simple long listings (ls -l, -la, -lh, -lA…: only those letters plus paths) go through
# eza, which colors each column: permissions per letter (r amber, w red, x green, - grey), your
# user in amber and others in grey, sizes in green with the unit apart, dates in cyan, links in
# cyan, git status and icons. Any other option (-t, -S, -R…) or no eza: the usual ls.
__ls_simple() {
    local a l=false
    for a; do
        [[ $a == -- ]] && break
        [[ $a == -* ]] || continue
        [[ $a =~ ^-[lahA1]+$ ]] || return 1
        [[ $a == *l* ]] && l=true
    done
    $l
}
# Arch's ~/.bashrc ships «alias ls='ls --color=auto'»: if it is still set, bash expands it when reading
# «ls() {» and fails with a syntax error. It is removed, and with «function ls» the name is not expanded either
unalias ls 2>/dev/null
function ls {
    if [[ -t 1 ]] && command -v eza >/dev/null && __ls_simple "$@"; then
        local a args=() ocultos=()
        for a; do
            if [[ $a == -[lahA1]* ]]; then
                [[ $a == *[aA]* ]] && ocultos=(-a)
            else
                args+=("$a")
            fi
        done
        eza -l -g "${ocultos[@]}" --group-directories-first --time-style=long-iso --git --icons=auto \
            "${args[@]}"
    else
        command ls --color=auto --group-directories-first "$@"
    fi
}
# eza colors, with alacritty.toml's palette (32 green, 33 amber, 31 red, 36 cyan, 90 grey)
export EZA_COLORS='ur=33:uw=31:ux=1;32:ue=1;32:gr=33:gw=31:gx=32:tr=33:tw=31:tx=32:su=1;35:sf=35:xa=90:xx=90:uu=1;33:uR=1;91:un=90:gu=33:gR=91:gn=90:sn=32:sb=2;32:df=32:ds=32:lc=35:lm=1;35:da=36:lp=36:bO=91:ga=32:gm=33:gd=31:gv=35:gt=35:gi=90:gc=1;91'
alias ll='ls -lh'
alias la='ls -lAh'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'
export GCC_COLORS='error=01;31:warning=01;33:note=01;36:caret=01;32:locus=01:quote=01'
# Colored man pages: titles in coral, underlined text in cyan and the status bar in maroon
export LESS_TERMCAP_md=$'\e[1;94m' LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;36m' LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;97;41m' LESS_TERMCAP_se=$'\e[0m'
export MANROFFOPT=-c

# --- Prompt ---
# Text coming from outside (folders, branch, environment) is not put into PS1 as is, since PS1 interprets
# \ and $: it goes into variables (__p_v) that PS1 names and bash expands without interpreting them again
__p_var() {
    __p_v+=("$1")
    __p_out+="\${__p_v[${#__p_v[@]}-1]}"
}

__p_dir() {
    local ruta=$PWD icono=$'\xef\x81\xbb' cab=''
    if [[ $ruta == "$HOME" ]]; then
        ruta='~' icono=$'\xef\x80\x95'
    elif [[ $ruta == "$HOME"/* ]]; then
        ruta="~${ruta#"$HOME"}" icono=$'\xef\x80\x95'
    elif [[ $ruta == / ]]; then
        __p_out+="\[\e[94m\]$icono \[\e[1m\]/\[\e[0m\]"
        return
    fi
    # Shortens long paths: first folder + … + the last 3
    local IFS=/ partes
    read -ra partes <<<"$ruta"
    local n=${#partes[@]}
    if (( n > 5 )); then
        cab="${partes[0]}/…/${partes[n-3]}/${partes[n-2]}/"
    elif (( n > 1 )); then
        cab="${ruta%/*}/"
    fi
    __p_out+="\[\e[94m\]$icono \[\e[34m\]"
    __p_var "$cab"
    __p_out+="\[\e[1;94m\]"
    __p_var "${partes[n-1]}"
    __p_out+="\[\e[0m\]"
}

__p_git() {
    local linea rama='' ab='' sube=0 baja=0 prep=0 mod=0 conf=0 nuevos=0 x y
    command -v git >/dev/null || return
    while IFS= read -r linea; do
        case $linea in
        '# branch.head '*) rama=${linea#'# branch.head '} ;;
        '# branch.oid '*) ab=${linea#'# branch.oid '} ;;
        '# branch.ab '*)
            linea=${linea#'# branch.ab +'}
            sube=${linea%% *}; baja=${linea##*-} ;;
        '1 '* | '2 '*)
            x=${linea:2:1} y=${linea:3:1}
            [[ $x != . ]] && ((prep++))
            [[ $y != . ]] && ((mod++)) ;;
        'u '*) ((conf++)) ;;
        '? '*) ((nuevos++)) ;;
        esac
    done < <(git status --porcelain=v2 --branch 2>/dev/null)
    [[ -n $rama ]] || return
    [[ $rama == '(detached)' ]] && rama=${ab:0:7}
    __p_out+="  \[\e[35m\]"$'\xee\x9c\xa5'" "
    __p_var "$rama"
    ((sube)) && __p_out+=" \[\e[36m\]⇡$sube"
    ((baja)) && __p_out+=" \[\e[36m\]⇣$baja"
    ((prep)) && __p_out+=" \[\e[32m\]+$prep"
    ((mod)) && __p_out+=" \[\e[33m\]~$mod"
    ((conf)) && __p_out+=" \[\e[91m\]!$conf"
    ((nuevos)) && __p_out+=" \[\e[90m\]?$nuevos"
    __p_out+='\[\e[0m\]'
}

__p_prompt() {
    local estado=$? __p_out='' flecha=32 trabajos
    trabajos=$(jobs -p | wc -l)
    __p_v=()
    # Window title: the current folder
    printf '\e]0;%s\a' "${PWD/#"$HOME"/\~}"

    if (( EUID == 0 )); then
        __p_out+="\[\e[1;91m\]\u@\h\[\e[0m\] "
    elif [[ -n $SSH_CONNECTION ]]; then
        __p_out+="\[\e[93m\]\u\[\e[90m\]@\[\e[93m\]\h\[\e[0m\] "
    fi
    __p_dir
    __p_git
    if [[ -n $VIRTUAL_ENV ]]; then
        __p_out+="  \[\e[33m\]"$'\xee\x9c\xbc'" "
        __p_var "${VIRTUAL_ENV##*/}"
        __p_out+="\[\e[0m\]"
    fi
    ((trabajos)) && __p_out+="  \[\e[36m\]"$'\xef\x80\x93'" $trabajos\[\e[0m\]"
    if ((estado)); then
        __p_out+="  \[\e[91m\]✘ $estado\[\e[0m\]"
        flecha=91
    fi
    PS1="\n$__p_out\n\[\e[1;${flecha}m\]❯\[\e[0m\] "
}

VIRTUAL_ENV_DISABLE_PROMPT=1
PS2='\[\e[90m\]… \[\e[0m\]'
# __p_prompt goes first to read the last command's $?
[[ $PROMPT_COMMAND == __p_prompt* ]] || PROMPT_COMMAND="__p_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

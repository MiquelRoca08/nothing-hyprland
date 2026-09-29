# Shared functions for install.sh's modules (loaded with «source»; not run on its own).
#
# Every action goes through paso(): it says what it will do, shows the exact command and asks
#   y     yes (Enter too)
#   n     no: skip the rest of this module and go on with the next one
#   yall  yes to all: no more questions until the end (unless something fails)
#   q     quit the installer
# If a command fails it always asks (even after yall): retry, continue, skip the
# module or quit. Each module runs in a subshell: «skip» means exiting it with SALTAR.

# Texts in the interface language (English; Spanish from the shell's dictionary): t "text"
# shellcheck source=/dev/null
source "$DOT/home/.config/quickshell/i18n/i18n.sh" 2>/dev/null ||
    t() { local s=$1; shift; if (($#)); then printf -- "$s" "$@"; else printf '%s' "$s"; fi; }

SALTAR=10     # exit code of a skipped module
SALIR=11      # exit code to stop the installer

# Colors (the theme's: red for what needs attention, grey for secondary text)
if [ -t 1 ]; then
    R=$'\e[31m' B=$'\e[1m' G=$'\e[90m' V=$'\e[32m' A=$'\e[33m' N=$'\e[0m'
else
    R='' B='' G='' V='' A='' N=''
fi

info()  { printf '  %s\n' "$*"; }
hecho() { printf '  %s✓%s %s\n' "$V" "$N" "$*"; }
aviso() { printf '  %s!%s %s\n' "$A" "$N" "$*" >&2; }
nada()  { printf '  %s✓ %s%s\n' "$G" "$(t "Nothing to do: %s" "$*")" "$N"; }

# Package names from a list file, without comments or empty lines
leer() { sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$1"; }

# The command as it will run (shortened if very long, e.g. a package list)
# (arguments with spaces or symbols in single quotes, as you would type them)
mostrar() {
    local a s="" q="'"
    for a; do
        if [[ $a =~ ^[][A-Za-z0-9_./:=@+,%~-]+$ ]]; then s+=" $a"; else s+=" '${a//$q/$q\\$q$q}'"; fi
    done
    s=${s# }
    ((${#s} > 400)) && s="${s:0:400}… ($(t "%s arguments" "$#"))"
    printf '%s' "$s"
}

# preguntar "text": 0 yes, 1 no; yall is remembered for the rest of the run; q quits
preguntar() {
    [ -e "$ESTADO/yall" ] && return 0
    local r
    while :; do
        printf '  %s%s%s [%sy%s]es / [%sn%s]o, %s / [%syall%s] %s / [q] %s: ' \
            "$B" "$1" "$N" "$R" "$N" "$R" "$N" "$(t "skip module")" "$R" "$N" "$(t "yes to all")" "$(t quit)"
        read -r r </dev/tty || exit $SALIR
        case ${r,,} in
        "" | y | yes | s | si | sí) return 0 ;;
        n | no) return 1 ;;
        yall | a | all | ya) touch "$ESTADO/yall"; return 0 ;;
        q | salir | exit) exit $SALIR ;;
        *) info "$(t "Answer y, n, yall or q")" ;;
        esac
    done
}

# ejecutar command…: if it fails, ask what to do (always, even after yall)
ejecutar() {
    local rc r
    while :; do
        "$@" && return 0
        rc=$?
        printf '  %s✗ %s:%s %s\n' "$R" "$(t "Failed (code %s)" "$rc")" "$N" "$(mostrar "$@")" >&2
        while :; do
            printf '  [%sr%s] %s / [%sc%s] %s / [%sn%s] %s / [%sq%s] %s: ' \
                "$R" "$N" "$(t retry)" "$R" "$N" "$(t "continue anyway")" "$R" "$N" "$(t "skip module")" "$R" "$N" "$(t quit)"
            read -r r </dev/tty || exit $SALIR
            case ${r,,} in
            r) continue 2 ;;
            c) touch "$ESTADO/errores"; return 0 ;;
            n) touch "$ESTADO/errores"; exit $SALTAR ;;
            q) exit $SALIR ;;
            esac
        done
    done
}

# paso "what it does" command [args…]: describes it, shows the command, asks and runs it
paso() {
    local desc=$1; shift
    printf '\n  %s›%s %s%s%s\n' "$R" "$N" "$B" "$desc" "$N"
    printf '    %s$ %s%s\n' "$G" "$(mostrar "$@")" "$N"
    preguntar "$(t "Run it?")" || exit $SALTAR
    ejecutar "$@"
}

# --- Package list with each one's size (modules paquetes and aur) ---
# Repos: exact installed size of the current version (pacman -Si) and, for what is missing, what
# would really be installed counting dependencies (pacman -Sp --needed). AUR: the AUR does not publish
# sizes, so only installed ones are known (pacman -Qi); the rest show «?».
# «name<TAB>bytes» for each package, from the output of LC_ALL=C pacman -Si / -Qi
tamanos() {
    awk -F' *: ' '
        /^Name/ { n = $2 }
        /^Installed Size/ {
            split($2, a, " "); m = (a[2] == "KiB") ? 1024 : (a[2] == "MiB") ? 1048576 : (a[2] == "GiB") ? 1073741824 : 1
            if (!(n in visto)) { visto[n] = 1; printf "%s\t%.0f\n", n, a[1] * m } }'
}

# bytes → «12.3 MiB» (decimal comma in Spanish)
humano() {
    awk -v b="${1:-0}" -v coma="$([[ $I18N_LANG == es ]] && echo 1)" 'BEGIN {
        split("B KiB MiB GiB TiB", u, " "); i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        s = (i == 1) ? sprintf("%d %s", b, u[i]) : sprintf("%.1f %s", b, u[i]); if (coma) gsub(/\./, ",", s); print s }'
}

# fila_peso «size  name  state»
fila_peso() { printf '  %10s  %-34s %s\n' "$1" "$2" "$3"; }

lista_repos() {   # paquetes.txt with each one's size, largest first, and the totals
    local lista n b nuevos=() total=0 hay=0 falta=0 nhay=0 nfalta=0
    declare -A tam inst
    mapfile -t lista < <(leer "$DOT/paquetes.txt")
    while IFS=$'\t' read -r n b; do tam[$n]=$b; done < <(LC_ALL=C pacman -Si "${lista[@]}" 2>/dev/null | tamanos)
    while read -r n; do inst[$n]=1; done < <(pacman -Qq "${lista[@]}" 2>/dev/null)

    printf '\n%s%s%s %s(%s)%s\n' "$B" "$(t "Packages from the repositories")" "$N" "$G" "$(t "paquetes.txt, installed size")" "$N"
    for n in "${lista[@]}"; do
        if [ -z "${tam[$n]:-}" ]; then printf '0\t%s\t%s\n' "$n" "$(t "not in the repositories")"; continue; fi
        if [ -n "${inst[$n]:-}" ]; then printf '%s\t%s\tinstalado\n' "${tam[$n]:-}" "$n"
        else printf '%s\t%s\tnuevo\n' "${tam[$n]:-}" "$n"; fi
    done | sort -t$'\t' -k1,1nr | while IFS=$'\t' read -r b n e; do
        case $e in
        instalado) fila_peso "$(humano "$b")" "$n" "${V}✓${N}" ;;
        nuevo) fila_peso "$(humano "$b")" "$n" "${R}$(t new)${N}" ;;
        *) fila_peso "?" "$n" "${G}$e${N}" ;;
        esac
    done

    for n in "${lista[@]}"; do
        [ -n "${tam[$n]:-}" ] || continue
        total=$((total + ${tam[$n]:-0}))
        if [ -n "${inst[$n]:-}" ]; then hay=$((hay + tam[$n])); nhay=$((nhay + 1))
        else falta=$((falta + tam[$n])); nfalta=$((nfalta + 1)); nuevos+=("$n"); fi
    done
    printf '  %s\n' "${G}──────────${N}"
    printf '  %s%s%s %s\n' "$B" "$(t "Total: %s" "$(humano "$total")")" "$N" \
        "$(t "in %s packages (%s already installed, %s · %s new, %s)" "$((nhay + nfalta))" "$nhay" "$(humano "$hay")" "$nfalta" "$(humano "$falta")")"
    # What would really be installed: the new ones plus the dependencies not yet present
    if ((nfalta)); then
        local deps=() sd=0
        mapfile -t deps < <(pacman -Sp --needed --print-format '%n' "${nuevos[@]}" 2>/dev/null)
        if ((${#deps[@]})); then
            while IFS=$'\t' read -r n b; do sd=$((sd + b)); done < <(LC_ALL=C pacman -Si "${deps[@]}" 2>/dev/null | tamanos)
            printf '  %s\n' "$(t "With dependencies, to install: %s in %s packages" "$(humano "$sd")" "${#deps[@]}")"
        fi
    fi
}

lista_aur() {     # paquetes-aur.txt: the AUR does not publish sizes, only installed ones are known
    local lista n b total=0 nq=0
    declare -A tam
    mapfile -t lista < <(leer "$DOT/paquetes-aur.txt")
    while IFS=$'\t' read -r n b; do tam[$n]=$b; done < <(LC_ALL=C pacman -Qi "${lista[@]}" 2>/dev/null | tamanos)

    printf '\n%s%s%s %s(%s)%s\n' "$B" "$(t "AUR packages")" "$N" "$G" "$(t "paquetes-aur.txt; the AUR does not publish sizes: installed ones only")" "$N"
    for n in "${lista[@]}"; do
        if [ -n "${tam[$n]:-}" ]; then printf '%s\t%s\n' "${tam[$n]:-}" "$n"; else printf -- '-1\t%s\n' "$n"; fi
    done | sort -t$'\t' -k1,1nr | while IFS=$'\t' read -r b n; do
        if ((b < 0)); then fila_peso "?" "$n" "${R}$(t new)${N} ${G}($(t "unknown size"))${N}"
        else fila_peso "$(humano "$b")" "$n" "${V}✓${N}"; fi
    done
    for n in "${lista[@]}"; do
        if [ -n "${tam[$n]:-}" ]; then total=$((total + ${tam[$n]:-0})); else nq=$((nq + 1)); fi
    done
    printf '  %s\n' "${G}──────────${N}"
    printf '  %s%s%s %s' "$B" "$(t "Total: %s" "$(humano "$total")")" "$N" "$(t "in %s packages" "${#lista[@]}")"
    ((nq)) && printf ' %s' "$(t "(plus %s not installed, of unknown size)" "$nq")"
    echo
}


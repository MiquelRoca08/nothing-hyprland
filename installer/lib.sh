# Shared functions for install.sh's modules (loaded with «source»; not run on its own).
#
# Every action goes through step(): it says what it will do, shows the exact command and asks
#   y     yes (Enter too)
#   n     no: skip the rest of this module and go on with the next one
#   yall  yes to all: no more questions until the end (unless something fails)
#   q     quit the installer
# If a command fails it always asks (even after yall): retry, continue, skip the
# module or quit. Each module runs in a subshell: «skip» means exiting it with SKIP.

# Texts in the interface language (English; Spanish from the shell's dictionary): t "text"
# shellcheck source=/dev/null
source "$DOT/home/.config/quickshell/i18n/i18n.sh" 2>/dev/null ||
    t() { local s=$1; shift; if (($#)); then printf -- "$s" "$@"; else printf '%s' "$s"; fi; }

SKIP=10     # exit code of a skipped module
QUIT=11      # exit code to stop the installer

# Colors (the theme's: red for what needs attention, grey for secondary text)
if [ -t 1 ]; then
    R=$'\e[31m' B=$'\e[1m' G=$'\e[90m' V=$'\e[32m' A=$'\e[33m' N=$'\e[0m'
else
    R='' B='' G='' V='' A='' N=''
fi

info()  { printf '  %s\n' "$*"; }
ok_msg() { printf '  %s✓%s %s\n' "$V" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$A" "$N" "$*" >&2; }
nothing_to_do()  { printf '  %s✓ %s%s\n' "$G" "$(t "Nothing to do: %s" "$*")" "$N"; }

# Package names from a list file, without comments or empty lines
read_list() { sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$1"; }

# --- Optional features (features.txt) and the ones you left out (excluded-features.txt, not in git) ---
FEATURES="$DOT/features.txt"
EXCLUDED="$DOT/excluded-features.txt"
feature_ids() { sed 's/#.*//' "$FEATURES" | awk -F'|' 'NF >= 3 { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1 }'; }
# feature_field id n: a column of features.txt (2 name, 3 packages, 4 services, 5 files), trimmed
feature_field() {
    sed 's/#.*//' "$FEATURES" | awk -F'|' -v id="$1" -v n="$2" '
        { f = $1; gsub(/^[ \t]+|[ \t]+$/, "", f) } f == id { v = $n; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit }'
}
excluded_ids() { [ -f "$EXCLUDED" ] && read_list "$EXCLUDED"; }
is_excluded() { excluded_ids | grep -qx "$1"; }
# What the excluded features take out, one per line: excluded_items 3 (packages), 4 (services), 5 (files)
excluded_items() { local id; for id in $(excluded_ids); do feature_field "$id" "$2" | tr ' ' '\n'; done | sed '/^$/d'; }
# A package list without the packages of the excluded features
read_packages() { read_list "$1" | grep -vxF -f <(excluded_items - 3; echo "//none//"); }

# The command as it will run (shortened if very long, e.g. a package list)
# (arguments with spaces or symbols in single quotes, as you would type them)
show_cmd() {
    local a s="" q="'"
    for a; do
        if [[ $a =~ ^[][A-Za-z0-9_./:=@+,%~-]+$ ]]; then s+=" $a"; else s+=" '${a//$q/$q\\$q$q}'"; fi
    done
    s=${s# }
    ((${#s} > 400)) && s="${s:0:400}… ($(t "%s arguments" "$#"))"
    printf '%s' "$s"
}

# ask "text": 0 yes, 1 no; yall is remembered for the rest of the run; q quits
ask() {
    [ -e "$STATE/yall" ] && return 0
    local r
    while :; do
        printf '  %s%s%s [%sy%s]es / [%sn%s]o, %s / [%syall%s] %s / [q] %s: ' \
            "$B" "$1" "$N" "$R" "$N" "$R" "$N" "$(t "skip module")" "$R" "$N" "$(t "yes to all")" "$(t quit)"
        read -r r </dev/tty || exit $QUIT
        case ${r,,} in
        "" | y | yes | s | si | sí) return 0 ;;
        n | no) return 1 ;;
        yall | a | all | ya) touch "$STATE/yall"; return 0 ;;
        q | salir | exit) exit $QUIT ;;
        *) info "$(t "Answer y, n, yall or q")" ;;
        esac
    done
}

# run_or_ask command…: if it fails, ask what to do (always, even after yall)
run_or_ask() {
    local rc r
    while :; do
        "$@" && return 0
        rc=$?
        printf '  %s✗ %s:%s %s\n' "$R" "$(t "Failed (code %s)" "$rc")" "$N" "$(show_cmd "$@")" >&2
        while :; do
            printf '  [%sr%s] %s / [%sc%s] %s / [%sn%s] %s / [%sq%s] %s: ' \
                "$R" "$N" "$(t retry)" "$R" "$N" "$(t "continue anyway")" "$R" "$N" "$(t "skip module")" "$R" "$N" "$(t quit)"
            read -r r </dev/tty || exit $QUIT
            case ${r,,} in
            r) continue 2 ;;
            c) touch "$STATE/errors"; return 0 ;;
            n) touch "$STATE/errors"; exit $SKIP ;;
            q) exit $QUIT ;;
            esac
        done
    done
}

# step "what it does" command [args…]: describes it, shows the command, asks and runs it
step() {
    local desc=$1; shift
    printf '\n  %s›%s %s%s%s\n' "$R" "$N" "$B" "$desc" "$N"
    printf '    %s$ %s%s\n' "$G" "$(show_cmd "$@")" "$N"
    ask "$(t "Run it?")" || exit $SKIP
    run_or_ask "$@"
}

# --- Package list with each one's size (modules packages and aur) ---
# Repos: exact installed size of the current version (pacman -Si) and, for what is missing, what
# would really be installed counting dependencies (pacman -Sp --needed). AUR: the AUR does not publish
# sizes, so only installed ones are known (pacman -Qi); the rest show «?».
# «name<TAB>bytes» for each package, from the output of LC_ALL=C pacman -Si / -Qi
parse_sizes() {
    awk -F' *: ' '
        /^Name/ { n = $2 }
        /^Installed Size/ {
            split($2, a, " "); m = (a[2] == "KiB") ? 1024 : (a[2] == "MiB") ? 1048576 : (a[2] == "GiB") ? 1073741824 : 1
            if (!(n in seen)) { seen[n] = 1; printf "%s\t%.0f\n", n, a[1] * m } }'
}

# bytes → «12.3 MiB» (decimal comma in Spanish)
human_size() {
    awk -v b="${1:-0}" -v comma="$([[ $I18N_LANG == es ]] && echo 1)" 'BEGIN {
        split("B KiB MiB GiB TiB", u, " "); i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        s = (i == 1) ? sprintf("%d %s", b, u[i]) : sprintf("%.1f %s", b, u[i]); if (comma) gsub(/\./, ",", s); print s }'
}

# size_row «size  name  state»
size_row() { printf '  %10s  %-34s %s\n' "$1" "$2" "$3"; }

list_repo_sizes() {   # packages.txt with each one's size, largest first, and the totals
    local list n b new_pkgs=() total=0 installed_bytes=0 missing_bytes=0 n_installed=0 n_missing=0
    declare -A size is_installed
    mapfile -t list < <(read_packages "$DOT/packages.txt")
    while IFS=$'\t' read -r n b; do size[$n]=$b; done < <(LC_ALL=C pacman -Si "${list[@]}" 2>/dev/null | parse_sizes)
    while read -r n; do is_installed[$n]=1; done < <(pacman -Qq "${list[@]}" 2>/dev/null)

    printf '\n%s%s%s %s(%s)%s\n' "$B" "$(t "Packages from the repositories")" "$N" "$G" "$(t "packages.txt, installed size")" "$N"
    for n in "${list[@]}"; do
        if [ -z "${size[$n]:-}" ]; then printf '0\t%s\t%s\n' "$n" "$(t "not in the repositories")"; continue; fi
        if [ -n "${is_installed[$n]:-}" ]; then printf '%s\t%s\tinstalled\n' "${size[$n]:-}" "$n"
        else printf '%s\t%s\tnew\n' "${size[$n]:-}" "$n"; fi
    done | sort -t$'\t' -k1,1nr | while IFS=$'\t' read -r b n e; do
        case $e in
        installed) size_row "$(human_size "$b")" "$n" "${V}✓${N}" ;;
        new) size_row "$(human_size "$b")" "$n" "${R}$(t new)${N}" ;;
        *) size_row "?" "$n" "${G}$e${N}" ;;
        esac
    done

    for n in "${list[@]}"; do
        [ -n "${size[$n]:-}" ] || continue
        total=$((total + ${size[$n]:-0}))
        if [ -n "${is_installed[$n]:-}" ]; then installed_bytes=$((installed_bytes + size[$n])); n_installed=$((n_installed + 1))
        else missing_bytes=$((missing_bytes + size[$n])); n_missing=$((n_missing + 1)); new_pkgs+=("$n"); fi
    done
    printf '  %s\n' "${G}──────────${N}"
    printf '  %s%s%s %s\n' "$B" "$(t "Total: %s" "$(human_size "$total")")" "$N" \
        "$(t "in %s packages (%s already installed, %s · %s new, %s)" "$((n_installed + n_missing))" "$n_installed" "$(human_size "$installed_bytes")" "$n_missing" "$(human_size "$missing_bytes")")"
    # What would really be installed: the new ones plus the dependencies not yet present
    if ((n_missing)); then
        local deps=() sd=0
        mapfile -t deps < <(pacman -Sp --needed --print-format '%n' "${new_pkgs[@]}" 2>/dev/null)
        if ((${#deps[@]})); then
            while IFS=$'\t' read -r n b; do sd=$((sd + b)); done < <(LC_ALL=C pacman -Si "${deps[@]}" 2>/dev/null | parse_sizes)
            printf '  %s\n' "$(t "With dependencies, to install: %s in %s packages" "$(human_size "$sd")" "${#deps[@]}")"
        fi
    fi
}

list_aur_sizes() {     # packages-aur.txt: the AUR does not publish sizes, only installed ones are known
    local list n b total=0 nq=0
    declare -A size
    mapfile -t list < <(read_packages "$DOT/packages-aur.txt")
    while IFS=$'\t' read -r n b; do size[$n]=$b; done < <(LC_ALL=C pacman -Qi "${list[@]}" 2>/dev/null | parse_sizes)

    printf '\n%s%s%s %s(%s)%s\n' "$B" "$(t "AUR packages")" "$N" "$G" "$(t "packages-aur.txt; the AUR does not publish sizes: installed ones only")" "$N"
    for n in "${list[@]}"; do
        if [ -n "${size[$n]:-}" ]; then printf '%s\t%s\n' "${size[$n]:-}" "$n"; else printf -- '-1\t%s\n' "$n"; fi
    done | sort -t$'\t' -k1,1nr | while IFS=$'\t' read -r b n; do
        if ((b < 0)); then size_row "?" "$n" "${R}$(t new)${N} ${G}($(t "unknown size"))${N}"
        else size_row "$(human_size "$b")" "$n" "${V}✓${N}"; fi
    done
    for n in "${list[@]}"; do
        if [ -n "${size[$n]:-}" ]; then total=$((total + ${size[$n]:-0})); else nq=$((nq + 1)); fi
    done
    printf '  %s\n' "${G}──────────${N}"
    printf '  %s%s%s %s' "$B" "$(t "Total: %s" "$(human_size "$total")")" "$N" "$(t "in %s packages" "${#list[@]}")"
    ((nq)) && printf ' %s' "$(t "(plus %s not installed, of unknown size)" "$nq")"
    echo
}


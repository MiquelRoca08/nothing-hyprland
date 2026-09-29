#!/usr/bin/env bash
# Data and actions for Settings → Connections → Printers (CUPS), as «field|field|…» lines:
#   status        cups|installed (1/0)|active (1/0)|ghostscript (1/0: without it nothing prints)
#                 printer|name|state (idle|printing|disabled)|default (1/0)|address|detail
#                 job|id|printer|user|bytes|state|date
#                 state (from «Alerts» in lpstat -l): queued | printing | stopped | held | error
#   discover      avahi|active (1/0)
#                 device|class (network|direct)|address|suggested name|description|address by IP
#                 (network: avahi-browse; USB: lpinfo if CUPS allows it; takes a few seconds)
#   set-default N      the user's default (lpoptions -d, no sudo)
#   test N             sends CUPS's test page
#   cancel ID          cancels a job
#   retry ID           resends a stopped job
# Adding and removing need sudo: Settings runs them in the terminal (lpadmin).
LC_ALL=C
export LC_ALL

case $1 in
status)
    gs=0; command -v gs >/dev/null && gs=1
    if ! command -v lpstat >/dev/null; then echo "cups|0|0|$gs"; exit 0; fi
    active=0; lpstat -r 2>/dev/null | grep -q 'is running' && active=1
    echo "cups|1|$active|$gs"
    ((active)) || exit 0
    def=$(lpstat -d 2>/dev/null | sed -n 's/^system default destination: //p')
    declare -A uri
    while read -r n u; do uri[$n]=$u; done < <(lpstat -v 2>/dev/null | sed -nE 's/^device for ([^:]+): (.*)/\1 \2/p')
    lpstat -p 2>/dev/null | awk -v def="$def" '
        /^printer / { if (n != "") print n "|" e "|" (n == def) "|" d
                      n = $2; d = ""
                      e = ($0 ~ /disabled/) ? "disabled" : ($0 ~ /now printing/) ? "printing" : "idle"; next }
        /^[ \t]/ { sub(/^[ \t]+/, ""); gsub(/\|/, "/"); d = d (d ? " " : "") $0 }
        END { if (n != "") print n "|" e "|" (n == def) "|" d }' |
        while IFS='|' read -r n e p d; do echo "printer|$n|$e|$p|${uri[$n]}|$d"; done
    lpstat -l -o 2>/dev/null | awk '
        function emit() { if (id != "") print "job|" id "|" dest "|" u "|" b "|" st "|" f }
        /^[^ \t]/ { emit(); id = $1; dest = id; sub(/-[0-9]+$/, "", dest); u = $2; b = $3; st = "queued"
                     $1 = $2 = $3 = ""; sub(/^ +/, ""); f = $0; next }
        /^[ \t]+Alerts:/ {
            if ($0 ~ /job-printing/) st = "printing"
            else if ($0 ~ /stopped|stop-point|canceled-at-device/) st = "stopped"
            else if ($0 ~ /hold/) st = "held"
            else if ($0 ~ /error|aborted/) st = "error" }
        END { emit() }'
    ;;
discover)
    # Network: what is announced over avahi (mDNS) as _ipp._tcp or _ipps._tcp (AirPrint, IPP Everywhere,
    # Mopria: almost every Wi-Fi printer). No root needed, unlike lpinfo (CUPS-Get-Devices requires
    # admin). The address is dnssd://<name>._ipp._tcp.local/: CUPS resolves it through
    # avahi, so it keeps working even if the printer changes IP.
    if systemctl is-active --quiet avahi-daemon 2>/dev/null || pgrep -x avahi-daemon >/dev/null; then echo "avahi|1"; else echo "avahi|0"; fi
    if command -v avahi-browse >/dev/null; then
        timeout 12 avahi-browse -rpt _ipp._tcp 2>/dev/null
        timeout 12 avahi-browse -rpt _ipps._tcp 2>/dev/null
    fi | awk -F';' '
        BEGIN { for (c = 0; c < 256; c++) ord[sprintf("%c", c)] = c }
        # avahi escapes with \DDD (decimal): \032 is a space
        function unescape(s,  o, m) { o = ""
            while (match(s, /\\[0-9][0-9][0-9]/)) { o = o substr(s, 1, RSTART - 1) sprintf("%c", substr(s, RSTART + 1, 3) + 0); s = substr(s, RSTART + 4) }
            return o s }
        function url(s,  o, i, ch) { o = ""
            for (i = 1; i <= length(s); i++) { ch = substr(s, i, 1)
                o = o (ch ~ /[A-Za-z0-9._~-]/ ? ch : sprintf("%%%02X", ord[ch])) }
            return o }
        # One per name (it shows up over IPv4 and IPv6, and as ipp and ipps): the first one, with IPv4 if any
        $1 == "=" {
            k = $4
            if (!(k in row)) order[++n] = k
            else if ((k in v4) || $3 != "IPv4") next
            if ($3 == "IPv4") v4[k] = 1
            name = unescape($4); ty = ""; if (match($0, /"ty=[^"]*"/)) ty = substr($0, RSTART + 4, RLENGTH - 5)
            if (k in svc) t = svc[k]; else t = svc[k] = $5
            s = (ty != "" ? ty : name); gsub(/[^A-Za-z0-9_-]+/, "_", s); gsub(/^_+|_+$/, "", s)
            d = (ty != "" ? ty : name) " · " $8; gsub(/\|/, "/", d)
            # Also by IP, in case the .local name does not resolve (no nss-mdns in nsswitch.conf)
            rp = "ipp/print"; if (match($0, /"rp=[^"]*"/)) rp = substr($0, RSTART + 4, RLENGTH - 5)
            host = ($3 == "IPv6" ? "[" $8 "]" : $8)
            ipuri = ($5 ~ /ipps/ ? "ipps" : "ipp") "://" host ":" $9 "/" rp
            row[k] = "device|network|dnssd://" url(name) "." t ".local/|" substr(s, 1, 40) "|" d "|" ipuri }
        END { for (i = 1; i <= n; i++) print row[order[i]] }'
    # USB: lpinfo only if allowed (without permissions CUPS answers «Forbidden»)
    if command -v lpinfo >/dev/null; then
        timeout 15 lpinfo --include-schemes usb -l -v 2>/dev/null | awk '
            function emit() { if (u != "" && u != "usb") {
                n = (m != "" ? m : i); gsub(/[^A-Za-z0-9_-]+/, "_", n); gsub(/^_+|_+$/, "", n)
                dd = (i != "" ? i : m); gsub(/\|/, "/", dd); print "device|direct|" u "|" substr(n, 1, 40) "|" dd } }
            /^Device: uri = / { emit(); u = $4; m = ""; i = ""; next }
            /^[ \t]+make-and-model = / { sub(/^[ \t]+make-and-model = /, ""); m = $0 }
            /^[ \t]+info = / { sub(/^[ \t]+info = /, ""); i = $0 }
            END { emit() }'
    fi
    ;;
set-default) lpoptions -d "$2" >/dev/null ;;
test)
    f=/usr/share/cups/data/testprint
    [[ -f $f ]] || { echo "$f is missing" >&2; exit 1; }
    lp -d "$2" -t "Test page" "$f"
    ;;
cancel) cancel "$2" ;;
retry) lp -i "$2" -H restart >/dev/null ;;
*) echo "usage: $0 status | discover | set-default N | test N | cancel ID | retry ID" >&2; exit 1 ;;
esac

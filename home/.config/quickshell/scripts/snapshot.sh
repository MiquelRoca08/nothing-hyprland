#!/usr/bin/env bash
# Snapper snapshot without updating (Settings → Updates). Same as arch-update's:
# -c number + cleanup number, so with NUMBER_LIMIT=1 it replaces the previous one (each snapshot
# carries its copy of the UKI in /boot, which has no room for several). limine-snapper-sync adds it to
# Limine's menu; since that can leave Limine unsigned, sbctl checks it at the end.
#   snapshot.sh ["description"]
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/../i18n/i18n.sh" 2>/dev/null ||
    t() { local s=$1; shift; if (($#)); then printf -- "$s" "$@"; else printf '%s' "$s"; fi; }
desc=${1:-}
desc="Manual $(date '+%Y-%m-%d %H:%M')${desc:+ · $desc}"

echo "Snapshot: $desc"
echo "$(t "It replaces the previous one (only one is kept).")"
echo
sudo snapper -c root create -c number --description "$desc" || { echo "$(t "Could not create the snapshot")"; exit 1; }
sudo snapper -c root cleanup number || echo "$(t "Warning: snapper cleanup failed: more than one may be left")"
echo
sudo snapper -c root list | tail -n +1

if command -v sbctl >/dev/null; then
    sleep 3   # limine-snapper-sync rewrites the menu in the background
    sin_firmar=$(sudo sbctl verify 2>&1 | grep -E ' is not signed' | grep -v vmlinuz)
    if [[ -n $sin_firmar ]]; then
        echo; echo "$(t "Unsigned boot files: signing them again")"
        echo "$sin_firmar"
        sudo sbctl sign-all && echo "$(t "Signed again")"
    fi
fi
echo; echo "$(t "Done. It shows in the Limine menu («Snapshots»).")"

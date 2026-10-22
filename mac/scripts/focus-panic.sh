#!/usr/bin/env bash
# Super+Ctrl+Alt+Backspace inside Deep Focus.
# If the shell is alive this only opens the normal (high-friction) exit flow.
# If the shell has died, it undoes the Hyprland lockdown so you are not stuck.
if qs -c mac ipc call focus ping >/dev/null 2>&1; then
    qs -c mac ipc call focus exit
    exit 0
fi
hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
hyprctl eval 'hl.config({ gestures = { workspace_swipe_distance = 300 } })' >/dev/null
# Clear the persisted session so the shell doesn't re-lock when it comes back.
for f in "$HOME"/.local/state/quickshell/by-shell/*/settings.json; do
    [ -f "$f" ] && python3 - "$f" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["focus"] = {"active": False}
json.dump(d, open(p, "w"), indent=4)
PY
done
notify-send -a "Deep Focus" "Lockdown released" "The shell was not running, so Deep Focus was ended. Restarting the shell."
setsid -f qs -c mac >/dev/null 2>&1

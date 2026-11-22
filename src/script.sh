#!/usr/bin/env bash
# Usage:  source script.sh   (or: . script.sh)
# Installs clipboard dependencies, adds a `copy` command (cat file | copy),
# and activates it in the current terminal. Prints only "Success" when done.

_setup_main() {
    local LOG SUDO MARKER BLOCK rc
    LOG="$(mktemp /tmp/setup-XXXXXX.log)"
    export DEBIAN_FRONTEND=noninteractive

    # Use sudo only when not already root
    if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

    # 1. Install dependencies (apt skips what is already installed)
    $SUDO apt-get update -y >>"$LOG" 2>&1 \
        || { echo "Failed. Details in: $LOG"; return 1; }
    $SUDO apt-get install -y curl unzip xclip wl-clipboard >>"$LOG" 2>&1 \
        || { echo "Failed. Details in: $LOG"; return 1; }

    # 2. Add the `copy` function to shell config files (only once)
    MARKER="# >>> clipboard helper >>>"
    BLOCK='
# >>> clipboard helper >>>
copy() {
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
        wl-copy
    else
        xclip -selection clipboard
    fi
}
# <<< clipboard helper <<<
'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ "$rc" = "$HOME/.bashrc" ] || [ -f "$rc" ]; then
            touch "$rc" || { echo "Failed. Cannot write $rc"; return 1; }
            if ! grep -qF "$MARKER" "$rc"; then
                printf '%s\n' "$BLOCK" >>"$rc" \
                    || { echo "Failed. Cannot write $rc"; return 1; }
            fi
        fi
    done
    return 0
}

_setup_main
_setup_rc=$?

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Sourced: we are inside the user's own shell, so we can activate it now
    if [ "$_setup_rc" -eq 0 ]; then
        # shellcheck disable=SC1090
        source "$HOME/.bashrc" >/dev/null 2>&1
        echo "Success"
    fi
    unset -f _setup_main
    _rc_final=$_setup_rc
    unset _setup_rc
    return "$_rc_final" 2>/dev/null
else
    # Executed as ./script.sh: a child process cannot change the parent shell
    if [ "$_setup_rc" -eq 0 ]; then
        echo "Success (open a new terminal, or run: source ~/.bashrc)"
    fi
    exit "$_setup_rc"
fi

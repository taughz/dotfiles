# Copyright (c) 2026 Tim Perkins

# NOTE This script is expected to be sourced!

# When using VTerm, include the Bash integration
if [ "${INSIDE_EMACS}" = "vterm" -a -n "${EMACS_VTERM_PATH}" \
        -a -f "${EMACS_VTERM_PATH}/etc/emacs-vterm-bash.sh" ]; then
    source "${EMACS_VTERM_PATH}/etc/emacs-vterm-bash.sh"
fi

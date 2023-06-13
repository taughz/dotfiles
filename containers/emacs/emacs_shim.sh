#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -e

# Launch Emacs in the background
if [ -z "${NO_EMACS_LAUNCH:-}" ]; then
    echo "Launching Emacs (Suppress this by setting NO_EMACS_LAUNCH)" >&2
    emacs &>/dev/null &
else
    echo "Skipping launch of Emacs (NO_EMACS_LAUNCH is set)" >&2
fi

exec "$@"

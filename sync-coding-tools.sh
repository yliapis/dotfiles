#!/usr/bin/env zsh
# sync-coding-tools.sh — thin wrapper around sync-coding-tools.py so callers
# (refresh.sh, install.sh, the user's shell) can invoke a single script name
# without caring about the implementation language. Stdlib-only Python 3.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
exec /usr/bin/env python3 "$SCRIPT_DIR/sync-coding-tools.py" "$@"

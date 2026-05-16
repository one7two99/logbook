#!/bin/bash
# logbook installer — copies files into XDG locations and reports.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
FISH_CONF="${XDG_CONFIG_HOME:-${HOME}/.config}/fish/conf.d"
DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/logbook"

# --- sanity checks
command -v python3 >/dev/null || { echo "✗ python3 not found in PATH" >&2; exit 1; }
PY_MIN=3.11
PY_VER="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')"
if [ "$(printf '%s\n%s\n' "$PY_MIN" "$PY_VER" | sort -V | head -n1)" != "$PY_MIN" ]; then
    echo "✗ python3 >= ${PY_MIN} required (found ${PY_VER})" >&2
    exit 1
fi

# --- install binary
echo "→ Installing binary to ${BIN_DIR}/logbook"
mkdir -p "$BIN_DIR"
install -m 0755 "${SCRIPT_DIR}/logbook" "${BIN_DIR}/logbook"

# --- install fish hook
echo "→ Installing fish hook to ${FISH_CONF}/logbook.fish"
mkdir -p "$FISH_CONF"
install -m 0644 "${SCRIPT_DIR}/logbook.fish" "${FISH_CONF}/logbook.fish"

# --- create data dir
echo "→ Creating data dir ${DATA_DIR}/sessions"
mkdir -p "${DATA_DIR}/sessions"

# --- PATH sanity
case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *)
        echo "⚠  ${BIN_DIR} is not in \$PATH"
        echo "   add via fish:  fish_add_path ${BIN_DIR}"
        ;;
esac

echo
echo "✓ Installed."
echo
echo "Next:"
echo "  1) Open a new fish session (or: source ${FISH_CONF}/logbook.fish)"
echo "  2) logbook init my-setup"
echo "  3) work as usual — commands get recorded"
echo "  4) logbook render        # → Markdown on stdout"

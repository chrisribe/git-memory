#!/usr/bin/env bash
# install.sh — install git-mem to ~/.local/bin
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$INSTALL_DIR"
cp git-mem "$INSTALL_DIR/git-mem"
chmod +x "$INSTALL_DIR/git-mem"

echo "Installed git-mem to $INSTALL_DIR/git-mem"

# Check if install dir is on PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo ""
    echo "Warning: $INSTALL_DIR is not on your \$PATH."

    # Detect shell profile
    if [[ "$OSTYPE" == msys* ]] || [[ "$OSTYPE" == mingw* ]]; then
        PROFILE="$HOME/.bashrc"  # Git Bash on Windows
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        PROFILE="$HOME/.zshrc"
    else
        PROFILE="$HOME/.bashrc"
    fi

    echo "Add this to $PROFILE:"
    echo ""
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    read -rp "Add it now? [y/N] " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "" >> "$PROFILE"
        echo "# git-mem" >> "$PROFILE"
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$PROFILE"
        echo "Added to $PROFILE. Run: source $PROFILE"
    fi
fi

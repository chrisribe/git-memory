#!/usr/bin/env bash
# install.sh — install git-mem CLI + skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${1:-$HOME/.local/bin}"
SKILL_DIR="$HOME/.agents/skills/git-memory"

# --- Get version from git ---
HASH=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(date +%Y-%m-%d)
VERSION="${HASH} (${DATE})"

# --- Install CLI ---
mkdir -p "$INSTALL_DIR"
# Stamp version into the installed copy
sed "s/^GIT_MEM_VERSION=.*/GIT_MEM_VERSION=\"${VERSION}\"/" "$SCRIPT_DIR/git-mem" > "$INSTALL_DIR/git-mem"
chmod +x "$INSTALL_DIR/git-mem"
echo "Installed git-mem to $INSTALL_DIR/git-mem"

# --- Install skill ---
mkdir -p "$SKILL_DIR"
# Stamp version into first line of body (after frontmatter closing ---)
awk -v ver="$VERSION" '
    /^---$/ && found==1 { print; print "> version: " ver; found=2; next }
    /^---$/ && found==0 { found=1 }
    { print }
' "$SCRIPT_DIR/SKILL.md" > "$SKILL_DIR/SKILL.md"
# Verify frontmatter starts at line 1
if [[ "$(head -1 "$SKILL_DIR/SKILL.md")" != "---" ]]; then
    echo "ERROR: SKILL.md frontmatter broken — version stamp not inline" >&2
    cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
fi
echo "Installed skill to $SKILL_DIR/SKILL.md"

echo ""
echo "Version: ${VERSION}"

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

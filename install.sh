#!/usr/bin/env bash
# install.sh — install git-mem CLI + skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

TARGET_HOME="${GIT_MEM_HOME:-$HOME}"
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    SUDO_HOME="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
    if [[ -n "$SUDO_HOME" ]]; then
        TARGET_HOME="$SUDO_HOME"
    fi
fi

INSTALL_DIR="${1:-$TARGET_HOME/.local/bin}"
SKILL_DIR="$TARGET_HOME/.agents/skills/git-memory"

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
if [[ "$TARGET_HOME" != "$HOME" ]]; then
    echo "Installing for user home: $TARGET_HOME"
fi

# On Windows, add a .cmd wrapper so PowerShell/cmd can invoke git-mem
if [[ "$OSTYPE" == msys* ]] || [[ "$OSTYPE" == mingw* ]] || [[ "$OSTYPE" == cygwin* ]]; then
    cat > "$INSTALL_DIR/git-mem.cmd" <<'CMDEOF'
@echo off
setlocal
set "GITDIR=C:\Program Files\Git"
if exist "%GITDIR%\bin\bash.exe" (
    set "PATH=%GITDIR%\bin;%GITDIR%\usr\bin;%PATH%"
    "%GITDIR%\bin\bash.exe" "%~dp0git-mem" %*
) else (
    bash "%~dp0git-mem" %*
)
CMDEOF
    echo "Installed git-mem.cmd (Windows wrapper)"
fi

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

# --- Init memory store on first install ---
MEMORY_DIR="${GIT_MEMORY_DIR:-$HOME/memory-store}"
if [[ -z "${GIT_MEMORY_DIR:-}" ]]; then
    MEMORY_DIR="$TARGET_HOME/memory-store"
fi
if [[ ! -d "$MEMORY_DIR/.git" ]]; then
    echo ""
    echo "Memory store not found at $MEMORY_DIR"
    read -rp "Initialize it now? [Y/n] " init_confirm
    if [[ "$init_confirm" != "n" && "$init_confirm" != "N" ]]; then
        "$INSTALL_DIR/git-mem" init
    fi
else
    count=$(git -C "$MEMORY_DIR" rev-list --count HEAD 2>/dev/null || echo 0)
    remote=$(git -C "$MEMORY_DIR" remote get-url origin 2>/dev/null || true)
    echo "Memory store: $MEMORY_DIR ($count memories)"
    if [[ -z "$remote" ]]; then
        echo ""
        echo "No remote configured. To connect an existing memories repo:"
        echo "  rm -rf ~/memory-store && git-mem init https://github.com/you/memories.git"
    fi
fi

# Check if install dir is on PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo ""
    echo "Warning: $INSTALL_DIR is not on your \$PATH."

    # Detect shell profile
    if [[ "$OSTYPE" == msys* ]] || [[ "$OSTYPE" == mingw* ]]; then
        PROFILE="$TARGET_HOME/.bashrc"  # Git Bash on Windows
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        PROFILE="$TARGET_HOME/.zshrc"
    else
        PROFILE="$TARGET_HOME/.bashrc"
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

echo ""
echo "Copilot skill path: $SKILL_DIR/SKILL.md"
echo "If you ran this with sudo before, check /root/.agents/skills/git-memory as well."
echo "In Copilot Chat, type /git-memory or ask to remember something to trigger the skill."

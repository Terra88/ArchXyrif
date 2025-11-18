#!/usr/bin/env bash
#  ArchXyrif Installer Color Theme
#  --------------------------------
#  Provides consistent color output for status, banners, errors,
#  and information messages across the entire installation script.
# ================================================================
#  COLOR DETECTION
# ================================================================
if [[ -t 1 ]]; then
    SUPPORTS_COLOR=true
else
    SUPPORTS_COLOR=false
fi

if $SUPPORTS_COLOR; then
    RESET="\033[0m"
    BOLD="\033[1m"

    RED="\033[1;31m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;34m"
    MAGENTA="\033[1;35m"
    CYAN="\033[1;36m"
    WHITE="\033[1;37m"
else
    RESET=""
    BOLD=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
fi

# ================================================================
#  FUNCTIONS — SYSTEM-STYLE OUTPUT
# ================================================================

# Informational message (pacman style)
info() {
    echo -e "${BLUE}==>${RESET} $1"
}

# Status update (yellow pacman style)
status() {
    echo -e "${YELLOW}==>${RESET} ${BOLD}$1${RESET}"
}

# Success message
success() {
    echo -e "${GREEN}✔${RESET} $1"
}

# Warning message
warn() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

# Error message
error() {
    echo -e "${RED}✘${RESET} $1"
}

# Section header (cyan)
section() {
    echo -e "${CYAN}#=======================================================================#${RESET}"
    echo -e "${CYAN}#  $1${RESET}"
    echo -e "${CYAN}#=======================================================================#${RESET}"
}

# Mini section header
subsection() {
    echo -e "${MAGENTA}---- $1 ----${RESET}"
}

# Highlight box (for warnings or choices)
highlight() {
    echo -e "${BOLD}${YELLOW}>>> $1 <<<${RESET}"
}

# Blank line helper
line() {
    echo ""
}

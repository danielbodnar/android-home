#!/usr/bin/env bash
# Dotfiles initialization script for a new Android terminal
# Uses Dorothy (https://github.com/bevry/dorothy) as the dotfiles manager
#
# Usage (run once on a fresh Android terminal / Termux install):
#   bash <(curl -fsSL 'https://raw.githubusercontent.com/danielbodnar/android-home/HEAD/init.sh')
#
# Or, if you have git available:
#   git clone 'https://github.com/danielbodnar/android-home.git' && bash android-home/init.sh

set -euo pipefail

DOTFILES_REPO='https://github.com/danielbodnar/android-home'

# ──────────────────────────────────────────────────────────────
# 1. Install prerequisites
# ──────────────────────────────────────────────────────────────

if command -v pkg >/dev/null 2>&1; then
	# Termux on Android — no sudo needed
	echo "Detected Termux environment. Installing prerequisites..."
	pkg update -y
	pkg install -y bash curl git
elif command -v apt-get >/dev/null 2>&1; then
	echo "Installing prerequisites via apt-get..."
	if command -v sudo >/dev/null 2>&1; then
		sudo apt-get update -y
		sudo apt-get install -y bash curl git
	else
		apt-get update -y
		apt-get install -y bash curl git
	fi
else
	echo "Unsupported environment: could not find 'pkg' (Termux) or 'apt-get'."
	echo "This installer currently supports Termux and Debian/Ubuntu-like systems."
	echo "Please ensure bash, curl, and git are installed manually, then re-run this script."
	exit 1
fi

# ──────────────────────────────────────────────────────────────
# 2. Install Dorothy and configure this repository as user dotfiles
# ──────────────────────────────────────────────────────────────

# The -i flag (interactive mode) is required by the Dorothy installer so that
# bash loads startup files (e.g. .bashrc) that Dorothy's bootstrap depends on.
# See the Dorothy README: https://github.com/bevry/dorothy#install
bash -ic "$(curl -fsSL 'https://dorothy.bevry.me/install')" -- install \
	--user="$DOTFILES_REPO"

#!/usr/bin/env bash
# install-amphetamine-power-protect.sh — Amphetamine Power Protect
# (https://x74353.github.io/Amphetamine-Power-Protect/). Not on Homebrew;
# the official payload is Install Power Protect.pkg inside the published
# DMG. install.sh runs this after Brewfile.mas when BREW_BUNDLE_MAS=1.
# The scripts/install-*.sh glob skips this file so it does not run twice
# or without the MAS bundle. Idempotent; safe to re-run directly.
#
# Apple Silicon only. The pkg postinstall uses ~, which becomes /var/root
# under `sudo installer`, so this script extracts the payload and writes
# the user-library script plus the sudoers drop-in itself.

set -euo pipefail

DMG_URL="https://github.com/x74353/Amphetamine-Power-Protect/raw/main/DMG/Power%20Protect%20for%20Amphetamine.dmg"
SCPT_DEST="$HOME/Library/Application Scripts/com.if.Amphetamine/powerProtect.scpt"
SUDOERS_DEST="/private/etc/sudoers.d/amphetamine_PowerProtect"
SUDOERS_DEST_ALT="/private/etc/sudoers.d/amphetamine_powerProtect"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "[install-amphetamine-power-protect] not macOS; skipping"
  exit 0
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "[install-amphetamine-power-protect] not Apple Silicon; skipping"
  exit 0
fi

if [ -f "$SCPT_DEST" ] && { [ -f "$SUDOERS_DEST" ] || [ -f "$SUDOERS_DEST_ALT" ]; }; then
  echo "[install-amphetamine-power-protect] already installed; skipping"
  exit 0
fi

if ! command -v hdiutil >/dev/null 2>&1 || ! command -v pkgutil >/dev/null 2>&1; then
  echo "[install-amphetamine-power-protect] hdiutil/pkgutil missing" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
mnt=""
cleanup() {
  if [ -n "$mnt" ]; then
    hdiutil detach "$mnt" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

extract_payload() {
  local pkg=$1 dest=$2 payload="" f
  if pkgutil --expand-full "$pkg" "$dest/full" 2>/dev/null; then
    return 0
  fi
  pkgutil --expand "$pkg" "$dest/expanded"
  while IFS= read -r f; do
    payload=$f
    break
  done < <(find "$dest/expanded" -name Payload -type f)
  if [ -z "$payload" ]; then
    echo "[install-amphetamine-power-protect] no Payload in the pkg" >&2
    return 1
  fi
  mkdir -p "$dest/full"
  gzip -dc "$payload" | (cd "$dest/full" && cpio -idmu)
}

echo "[install-amphetamine-power-protect] downloading official DMG"
dmg="$tmpdir/Power Protect for Amphetamine.dmg"
curl -fsSL -o "$dmg" "$DMG_URL"

mnt="$tmpdir/mnt"
mkdir -p "$mnt"
hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mnt"

pkg="$mnt/Install Power Protect.pkg"
if [ ! -f "$pkg" ]; then
  echo "[install-amphetamine-power-protect] Install Power Protect.pkg missing from the DMG" >&2
  exit 1
fi

extract_dir="$tmpdir/payload"
mkdir -p "$extract_dir"
extract_payload "$pkg" "$extract_dir"

scpt_src=""
sudoers_src=""
while IFS= read -r f; do
  scpt_src=$f
  break
done < <(find "$extract_dir" -name 'powerProtect.scpt' -type f)
while IFS= read -r f; do
  sudoers_src=$f
  break
done < <(find "$extract_dir" \( -name 'amphetamine_PowerProtect' -o -name 'amphetamine_powerProtect' \) -type f)

if [ -z "$scpt_src" ] || [ -z "$sudoers_src" ]; then
  echo "[install-amphetamine-power-protect] payload missing powerProtect.scpt or sudoers file" >&2
  exit 1
fi

echo "[install-amphetamine-power-protect] installing powerProtect.scpt"
mkdir -p "$(dirname "$SCPT_DEST")"
cp -f "$scpt_src" "$SCPT_DEST"

echo "[install-amphetamine-power-protect] installing $SUDOERS_DEST"
sudo install -m 0440 -o root -g wheel "$sudoers_src" "$SUDOERS_DEST"
if ! sudo visudo -c >/dev/null; then
  sudo rm -f "$SUDOERS_DEST"
  echo "[install-amphetamine-power-protect] visudo rejected the sudoers drop-in; removed it" >&2
  exit 1
fi

echo "[install-amphetamine-power-protect] installed"

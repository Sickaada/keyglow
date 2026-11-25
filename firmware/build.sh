#!/bin/bash
# Builds the KeyGlow firmware for the Keychron K3 Pro (ANSI, RGB).
# Needs: git, python3, and the Arm GNU toolchain (brew install --cask gcc-arm-embedded).
# Note: QMK can't build from a path that contains spaces.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HOME/.keyglow-build}"
KEYCHRON_COMMIT=618127a725a1773e85f13455602cf6f72ab4de17   # Keychron/qmk_firmware, branch bluetooth_playground

[[ "$WORK" == *" "* ]] && { echo "WORK path must not contain spaces: $WORK"; exit 1; }
command -v arm-none-eabi-gcc >/dev/null || export PATH="$(ls -d /Applications/ArmGNUToolchain/*/arm-none-eabi/bin 2>/dev/null | tail -1):$PATH"
command -v arm-none-eabi-gcc >/dev/null || { echo "arm-none-eabi-gcc not found. brew install --cask gcc-arm-embedded"; exit 1; }

if [[ ! -d "$WORK/qmk" ]]; then
  git clone --branch bluetooth_playground https://github.com/Keychron/qmk_firmware.git "$WORK/qmk"
fi
cd "$WORK/qmk"
git fetch --depth 1 origin "$KEYCHRON_COMMIT" 2>/dev/null || true
git checkout -q --force "$KEYCHRON_COMMIT"
git submodule update --init --recursive --depth 1

[[ -d "$WORK/venv" ]] || python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install -q qmk -r requirements.txt
export PATH="$WORK/venv/bin:$PATH"

git checkout -q -- keyboards/keychron/bluetooth/bluetooth.c
git apply "$HERE/patches/bluetooth-hid-indicator.patch"
KM=keyboards/keychron/k3_pro/ansi/rgb/keymaps/keyglow
rm -rf "$KM" && mkdir -p "$KM" && cp "$HERE"/keymap/* "$KM/"

make keychron/k3_pro/ansi/rgb:keyglow
cp keychron_k3_pro_ansi_rgb_keyglow.bin "$HERE/"
git checkout -q -- keyboards/keychron/bluetooth/bluetooth.c
echo "Firmware: $HERE/keychron_k3_pro_ansi_rgb_keyglow.bin"

#!/usr/bin/env bash
# twrp-server-setup.sh — one-shot TWRP build environment for a FRESH Linux box.
#
# Requirements for the server: >=16GB RAM (or 8GB + big swap), >=120GB free
# disk, x86_64, Debian 11/12 or Ubuntu 20.04+. Run as root.
#
# Usage: twrp-server-setup.sh <github-token> [device-tree-repo-url]
#   1. installs build deps + repo tool
#   2. creates swap sized to RAM
#   3. syncs minimal-manifest-twrp aosp twrp-12.1 (depth 1) with the
#      remove-heavy diet (154 projects dropped)
#   4. clones the star2lte device tree + blobs + tools
#   5. starts the recovery build with nohup; log at /opt/twrp/build.log
set -euo pipefail

TOKEN="${1:?usage: twrp-server-setup.sh <github-token> [tree-repo-url]}"
TREE_URL="${2:-https://github.com/Skyshadow2022/star2lte-twrp.git}"
ROOT=/opt/twrp

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
FREE_G=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
(( FREE_G >= 100 )) || { echo "need >=100GB free disk, have ${FREE_G}GB"; exit 1; }

echo "== deps =="
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential gcc-multilib g++-multilib lib32z1-dev lib32ncurses-dev \
  lib32stdc++6 bison flex zlib1g-dev libncurses-dev libssl-dev \
  libxml2-utils xsltproc unzip rsync curl git bc ccache python3 e2fsprogs

curl -s https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
chmod a+x /usr/local/bin/repo

echo "== swap =="
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
SWAP_MB=$(( RAM_KB / 1024 * 2 ))
[ "$SWAP_MB" -lt 12000 ] && SWAP_MB=12000
if ! swapon --show | grep -q /swapfile-twrp; then
  fallocate -l "${SWAP_MB}M" /swapfile-twrp
  chmod 600 /swapfile-twrp && mkswap /swapfile-twrp >/dev/null && swapon /swapfile-twrp
fi
free -h

echo "== sync =="
mkdir -p "$ROOT" && cd "$ROOT"
git config --global user.email ci@localhost; git config --global user.name CI
[ -d .repo ] || repo init -q -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1 --depth=1
mkdir -p .repo/local_manifests
git clone -q "https://x-access-token:${TOKEN}@github.com/Skyshadow2022/star2lte-twrp.git" star2lte-twrp-repo
cp star2lte-twrp-repo/local_manifests/*.xml .repo/local_manifests/
git clone -q "https://x-access-token:${TOKEN}@github.com/Skyshadow2022/kernel-s9plus-hdmi.git" kernel-repo 2>/dev/null || true
nohup repo sync -c -j"$(nproc)" --no-clone-bundle --no-tags > "$ROOT/sync.log" 2>&1 &
echo "sync started (log: $ROOT/sync.log) — when it finishes, run:"
echo "  cd $ROOT/star2lte-twrp-repo && bash scripts/contabo-build.sh"

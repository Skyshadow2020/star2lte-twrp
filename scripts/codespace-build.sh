#!/usr/bin/env bash
# codespace-build.sh — full TWRP build inside a GitHub Codespace (run under nohup).
# Log: /tmp/codespace-build.log
set -euo pipefail
exec >> /tmp/codespace-build.log 2>&1
echo "=== codespace build $(date) ==="

# deps (idempotent)
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bison flex zlib1g-dev \
  libncurses-dev libssl-dev libxml2-utils xsltproc rsync bc e2fsprogs unzip \
  build-essential gcc-multilib g++-multilib lib32z1-dev lib32ncurses-dev lib32stdc++6
mkdir -p ~/bin
curl -s https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo
echo "deps ok $(date)"

# swap AFTER sync (disk first, memory later)
free -h

# sync
mkdir -p ~/twrp && cd ~/twrp
[ -d .repo ] || ~/bin/repo init -q -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1 --depth=1
mkdir -p .repo/local_manifests
cp /workspaces/star2lte-twrp/local_manifests/*.xml .repo/local_manifests/
~/bin/repo sync -c -j4 --no-clone-bundle --no-tags
echo "sync done $(date)"
# swap after sync
sudo fallocate -l 8G /swapfile-cs && sudo chmod 600 /swapfile-cs && sudo mkswap /swapfile-cs >/dev/null && sudo swapon /swapfile-cs || true
free -h
df -h /
# slim the tree: git metadata not needed for the build
rm -rf .repo/projects .repo/project-objects
df -h /

# tree + blobs + flags
cd /workspaces/star2lte-twrp
bash setup-tree.sh
cd ~/twrp

# build
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_star2lte-eng
mka recoveryimage -j4
echo "mka done $(date)"

# samsung repack
python3 /workspaces/star2lte-twrp/tools/samsung_pack.py \
  /workspaces/star2lte-twrp/star2lte-twrp-base.img \
  out/target/product/star2lte/kernel \
  out/target/product/star2lte/ramdisk-recovery.img \
  /workspaces/star2lte-twrp/device/samsung/star2lte/prebuilt/dt \
  out/target/product/star2lte/recovery-samsung.img

# park artifacts on a branch so nothing is lost
cd /workspaces/star2lte-twrp
git config user.email ci@localhost; git config user.name CI
git checkout -q -B artifacts
cp /tmp/codespace-build.log build.log 2>/dev/null || true
git add -f ../twrp/out/target/product/star2lte/recovery-samsung.img \
           ../twrp/out/target/product/star2lte/recovery.img build.log 2>/dev/null || true
git commit -q -m "artifact: twrp recovery build $(date +%F-%H%M)" || true
git push -q -f origin artifacts && echo "ARTIFACT PUSHED"
echo "=== ALL DONE $(date) ==="

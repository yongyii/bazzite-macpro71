#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files"/. /

# ============================================================
# Bazzite MacPro7,1 + Apple T2
# ============================================================

dnf5 -y copr enable sharpenedblade/t2linux

T2_REPO="copr:copr.fedorainfracloud.org:sharpenedblade:t2linux"
T2_VER="7.1.6-201.t2.fc44"

# ------------------------------------------------------------
# Unlock Bazzite OGC kernel
# ------------------------------------------------------------

dnf5 versionlock delete \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core \
    kernel-modules-extra \
    kernel-devel \
    kernel-devel-matched \
    'kernel-*' \
    || true

# Bazzite excludes normal Fedora kernel packages.
# Preserve its Mesa/Steam exclusions while allowing kernel packages.
dnf5 config-manager setopt 'fedora.exclude=mesa-* steam' || true

# ------------------------------------------------------------
# Remove packages tied to Bazzite OGC kernel
# ------------------------------------------------------------

dnf5 -y remove \
    kmod-evdi \
    kmod-framework-laptop \
    framework-laptop-kmod-common \
    displaylink \
    kernel-devel-matched \
    || true

dnf5 -y remove \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-devel

# ------------------------------------------------------------
# Install dependencies needed by T2 kernel-devel
# from Fedora repos
# ------------------------------------------------------------

dnf5 -y install \
    bison \
    flex \
    openssl-devel \
    elfutils-libelf-devel

# ------------------------------------------------------------
# Install exact matching T2 kernel family
# ------------------------------------------------------------

dnf5 -y install \
    --repo "${T2_REPO}" \
    "kernel-${T2_VER}" \
    "kernel-core-${T2_VER}" \
    "kernel-modules-${T2_VER}" \
    "kernel-modules-core-${T2_VER}" \
    "kernel-modules-extra-${T2_VER}"

# ------------------------------------------------------------
# T2 userspace/configuration
# ------------------------------------------------------------

dnf5 -y install \
    --repo "${T2_REPO}" \
    t2linux-config \
    t2linux-scripts \
    t2fanrd

# Explicit module loading for Apple T2 BCE
cat > /usr/lib/modules-load.d/t2linux-modules.conf <<'MODULES'
t2bce_dma
t2bce_core
t2bce_vhci
MODULES

# Make sure modules are included in initramfs
mkdir -p /usr/lib/dracut/dracut.conf.d

cat > /usr/lib/dracut/dracut.conf.d/t2linux-modules-install.conf <<'DRACUT'
add_drivers+=" nvme nvme_core t2bce_dma t2bce_core t2bce_vhci "
DRACUT

# Disable Apple T2 internal audio on MacPro7,1.
#
# The t2bce_audio driver currently triggers a kernel NULL pointer
# dereference in t2audio_pcm_open and can leave WirePlumber/processes
# stuck in uninterruptible D state. Audio is provided by the Audigy card.
cat > /etc/modprobe.d/blacklist-t2bce-audio.conf <<'MODPROBE'
blacklist t2bce_audio
install t2bce_audio /bin/false
MODPROBE

cat > /usr/lib/dracut/dracut.conf.d/t2linux-audio-blacklist.conf <<'DRACUT_AUDIO'
omit_drivers+=" t2bce_audio "
DRACUT_AUDIO

# Enable T2 fan daemon by default.
# Verified working on MacPro7,1 with AppleSMC fan interfaces.
systemctl unmask t2fanrd.service || true
systemctl enable t2fanrd.service

# ------------------------------------------------------------
# Clean problematic third-party repos from final image
#
# bootc-image-builder previously failed because terra-mesa
# referenced a host-local GPG key that did not exist in BIB.
# ------------------------------------------------------------

dnf5 -y copr disable sharpenedblade/t2linux || true

rm -f /etc/yum.repos.d/terra*.repo
rm -f /usr/lib/yum.repos.d/terra*.repo

# Remove packages only needed while preparing the T2 kernel.
# Keeping build dependencies in the final bootc image can confuse
# rpm-ostree package metadata during rechunking.
dnf5 -y remove \
  bison \
  flex \
  openssl-devel \
  elfutils-libelf-devel \
  || true

dnf5 clean all

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------

echo "===== FINAL KERNEL ====="
rpm -qa | grep '^kernel' | sort

echo "===== FINAL T2 PACKAGES ====="
rpm -qa | grep -Ei '^t2' | sort || true

echo "===== T2 BCE MODULES ====="
for mod in t2bce_dma t2bce_core t2bce_vhci t2bce_audio; do
    modinfo -k "${T2_VER}.x86_64" "$mod" 2>/dev/null \
        | grep -E '^(filename|version|description|alias|depends|vermagic):' \
        || true
done

echo "===== FAN SERVICE ====="
systemctl is-enabled t2fanrd.service || true

echo "===== REPOSITORIES ====="
dnf5 repolist --all | grep -Ei 'terra|t2linux' || true

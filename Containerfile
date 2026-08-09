# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh


# Generate the bootable initramfs for the T2 kernel.
# bootc/OSTree expects this beside vmlinuz in /usr/lib/modules/$KVER/.
RUN set -eux; \
    KVER="$(find /usr/lib/modules \
      -mindepth 1 -maxdepth 1 -type d \
      -printf '%f\n' \
      | grep '\.t2\.fc' \
      | sort -V \
      | tail -1)"; \
    test -n "$KVER"; \
    echo "Generating initramfs for T2 kernel: $KVER"; \
    test -x /usr/bin/dracut; \
    test -d /usr/lib/dracut/modules.d/50ostree; \
    test -f "/usr/lib/modules/${KVER}/vmlinuz"; \
    depmod -a "$KVER"; \
    dracut \
      --force \
      --no-hostonly \
      --add "ostree" \
      --add-drivers "nvme nvme_core t2bce_dma t2bce_core t2bce_vhci t2bce_audio" \
      "/usr/lib/modules/${KVER}/initramfs.img" \
      "$KVER"; \
    test -s "/usr/lib/modules/${KVER}/initramfs.img"; \
    ls -lh \
      "/usr/lib/modules/${KVER}/vmlinuz" \
      "/usr/lib/modules/${KVER}/initramfs.img"


### LINTING
## Verify final image and contents are correct.
RUN bootc container lint

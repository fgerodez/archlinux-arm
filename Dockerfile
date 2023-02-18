FROM --platform=linux/amd64 archlinux:latest as build

ARG TARGET = arch-arm

RUN mkdir $TARGET

RUN echo 'Server = http://mirror.archlinuxarm.org/$arch/$repo' > /etc/pacman.d/mirrorlist \
	&& sed -i "s/#RootDir     = \//RootDir = \/${TARGET}/" /etc/pacman.conf \
	&& sed -i "s/Architecture = auto/Architecture = aarch64/" /etc/pacman.conf \
    && mkdir -p /arch-pi/var/lib/pacman

ADD install-arm-package.sh .

# Manually install the archlinuxarm keyring and load it
RUN pacman-key --init \
	&& ./install-arm-package.sh -p archlinuxarm-keyring / \
	&& pacman-key --populate archlinuxarm

# Bootstrap arm pacman & filesystem
RUN pacman --noconfirm -Sy \
	    pacman \
	    archlinuxarm-keyring \
	    filesystem

FROM scratch 

ARG TARGET

COPY --from=build ${TARGET}/ /

# To use this image as source start with the following command
#
# Note: This image doesn't contain a kernel, it must be added in a child
# image if necessary.
#
# FROM mahoneko/archlinux-arm:latest
#
# RUN pacman-key --init \
#	&& pacman-key --populate archlinuxarm \
#   && pacman -Sy
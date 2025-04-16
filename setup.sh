#!/bin/sh

# Git repository location
repository="https://github.com/mascencerro/RDPTerminalKit.git"
echo "Change server installer source location?"
echo "(default = ${repository})"

yn="N"
read -t 10 -p "[y/N]" yn </dev/tty

if [ "${yn}" = "y" ] || [ "${yn}" = "Y" ]; then
    read -p "New installer source location: " repository </dev/tty
fi

echo "Using source: ${repository}"

# OpenSSH client (not required for server operation)
# This is needed if 'repository' is set to a local network system user git repository
openssh_setup() {
    apk add openssh
}


get_repository() {
    apk add git
    git clone "${repository}"

}

unpack_files() {
    # Copy repository to correct locations
    echo "Copying files"
    cp -adr RDPTerminalKit/server_fs/srv /
    cp -adr RDPTerminalKit/server_fs/etc /

    chmod +x /srv/pack_client_fs.sh
    chmod +x /srv/local_repository_fill.sh
    sleep 10
    chmod +x /srv/ipxe/src/build.sh

    chown -R www:www "/srv/www"

}

apk_updates() {
    # Update and upgrade packages
    echo "Updating APK packages"
    apk update && apk upgrade
}

nginx_setup() {
    # Install NGINX for HTTP
    echo "Installing and configuring NGINX"
    apk add nginx
    adduser -D -g 'www' www
    chown -R www:www /var/lib/nginx
    rc-update add nginx
}

tftp_setup() {
    # Download Alpine netboot tarball and unpack
    echo "Setting up TFTP"
    mkdir -p "/srv/www/alpine"
    wget -qO - https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-netboot-3.21.3-x86_64.tar.gz | tar -zxv -C "/srv/www/alpine/"

    # Set up TFTP
    apk add tftp-hpa
    rc-update add in.tftpd
}

ipxe_setup() {
    # Set up iPXE
    echo "Setting up iPXE"
    apk add make binutils mtools perl xz-dev libc-dev gcc
    git clone https://github.com/ipxe/ipxe.git "/srv/ipxe"

    unpack_files

    cd "/srv/ipxe/src"
    ./build.sh
    cd

}

pack_client_fs() {
    sh /srv/pack_client_fs.sh
}

prepare_local_repository() {
    sh /srv/local_repository_fill.sh
}

start_services() {
    rc-service nginx start
    rc-service in.tftpd start

}

# OpenSSH client (not required for server operation)
# This is needed if 'repository' is set to a local network system user git repository
openssh_setup

get_repository
apk_updates

nginx_setup
tftp_setup
ipxe_setup

pack_client_fs
prepare_local_repository

start_services



echo "A base APK overlay is provided."
echo "If any customizations are needed to client filesystem, after customizations are made /srv/pack_client_fs.sh will need to be rerun as well as calling the bootstrap.sh script from the template creating system."
echo "Instructions for APK overlay creation with bootstrap.sh can be found in the bootstrap.sh script located in /srv/www/alpine/build."
echo ""
echo "Point netboot clients to $(ip -f inet addr show eth0 | grep inet | cut -d ' ' -f6 | cut -d '/' -f1)"



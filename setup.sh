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

server_ip="$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"

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

set_client_next_server() {
    echo "Setting client server address"
    echo "${server_ip}" > /srv/client_fs/etc/next_server
}

pack_client_fs() {
    echo "Making some changes to client filesystem and repacking"

    # Need GNU tar for this (busybox tar doesn't provide -r)
    apk add tar

    # Pack up client_fs tree for custom APK overlay build usage
    sh /srv/pack_client_fs.sh

    # Repackage changes made to client_fs files during server install
    # Uncompress APK overlay tarball
    gunzip /srv/www/alpine/client/thinclient.apkovl.tar.gz

    # etc/next_server
    tar --delete 'etc/next_server' -vf /srv/www/alpine/client/thinclient.apkovl.tar
    tar -vf /srv/www/alpine/client/thinclient.apkovl.tar -C /srv/client_fs/ -r 'etc/next_server'

    # etc/apk/repositories
    tar --delete 'etc/apk/repositories' -fv /srv/www/alpine/client/thinclient.apkovl.tar
    tar -vf /srv/www/alpine/client/thinclient.apkovl.tar -C /srv/client_fs/ -r 'etc/apk/repositories'

    # Compress APK overlay tarball
    gzip /srv/www/alpine/client/thinclient.apkovl.tar

}

prepare_local_repository() {
    echo "Creating local APK repository mirror"

    sh /srv/local_repository_fill.sh

    # Update client_fs /etc/apk/repositories and list local repository first
    echo -e "http://${server_ip}/mod\n$(cat /srv/client_fs/etc/apk/repositories)" > /srv/client_fs/etc/apk/repositories
    echo -e "http://${server_ip}/main\n$(cat /srv/client_fs/etc/apk/repositories)" > /srv/client_fs/etc/apk/repositories
    echo -e "http://${server_ip}/community\n$(cat /srv/client_fs/etc/apk/repositories)" > /srv/client_fs/etc/apk/repositories

}

start_services() {
    echo "Starting services"
    rc-service nginx start
    rc-service in.tftpd start

}

# OpenSSH *client* (not required for server operation)
# This is needed if 'repository' is set to a local network system user git repository
openssh_setup

get_repository
apk_updates

nginx_setup
tftp_setup
ipxe_setup
prepare_local_repository

set_client_next_server
pack_client_fs

start_services



echo "A base APK overlay is provided."
echo "If any customizations are needed to client filesystem, after customizations are made /srv/pack_client_fs.sh will need to be rerun as well as calling the bootstrap.sh script from the template creating system."
echo "Instructions for APK overlay creation with bootstrap.sh can be found in the bootstrap.sh script located in /srv/www/alpine/build."
echo ""
echo "Point netboot clients to $(ip -f inet addr show eth0 | grep inet | cut -d ' ' -f6 | cut -d '/' -f1)"



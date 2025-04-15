#!/bin/sh
# Creation of custom terminal client
# ----------------------------------
# Changes for client filesystem will be in /srv/client_fs
# To build client template filesystem tarball run /srv/client_fs_pack.sh after changes are made
#
# NOTE: There is also a script 'last_call.sh' that will be requested from the server on client boot
# Functionality can be added to this script without requiring rebuild of client APK overlay
#
#
# 1. Boot to Alpine image
# 2. Run the following from initial boot after root login (there is no password)
#
#   setup-interfaces -ar && wget -qO - http://[SERVER]/bootstrap.sh | sh
#
# * or to run script without prompt the [SERVER_ADDRESS] can be specified:
#
#   setup-interfaces -ar && wget -qO - http://[SERVER]/bootstrap.sh | sh -s -- [SERVER_ADDRESS]
#
# This will:
# 1. Set up base system
# 2. Create boot image file thinclient.apkovl.tar.gz in /root
# 3. Start busybox-extras httpd server in /root for retrieval of APK overlay to server
#
# Next steps:
# 1. Retrieve thinclient.apkovl.tar.gz using the URL specified when script finishes
# 2. Place on server filesystem where client is specified to locate (default /srv/www/alpine/client)

####################################################################################
# CONFIGURATION
####################################################################################
# SERVER_ADDR = Server address providing alpine SETUP_INI, CLIENT_FS, and LOCAL_REPOSITORY
#               Also where clients will be network booting from (default = netboot)
if [ $# -gt 0 ]; then
    SERVER_ADDR="${1}"
else
    read -p "Server address [default = netboot]: " SERVER_ADDR </dev/tty
    if [ -z ${SERVER_ADDR} ]; then
        SERVER_ADDR="netboot"
    fi
fi

# BUILD_URL = URL on SERVER_ADDR for locating SETUP_INI and CLIENT_FS
BUILD_URL="alpine/build"
# Initial configuration for setup-alpine
SETUP_INI="setup-alpine.ini"
# Additional files to be copied to /etc and /root before boot image creation
CLIENT_FS="client_fs.tar.gz"
TEMP="/dev/shm"
# If *NOT* hosting local repository for apk packages leave this empty or comment out
LOCAL_REPOSITORY="http://${SERVER_ADDR}/alpine/v3.21"
# APK Overlay filename
APKOVL_FILE="thinclient.apkovl.tar.gz"

echo ""
echo "-----------------------------------"
echo "Client Configuration"
echo "Server:                               ${SERVER_ADDR}"
echo "Alpine setup configuration:           http://${SERVER_ADDR}/${BUILD_URL}/${SETUP_INI}"
echo "Client filesystem content template:   http://${SERVER_ADDR}/${BUILD_URL}/${CLIENT_FS}"
echo "Local APK mirror:                     ${LOCAL_REPOSITORY}"
echo "-----------------------------------"
echo ""
read -t 5 -p "Press ENTER to continue or wait 5 seconds." TEMPVAR </dev/tty

#####################################################################################
# END CONFIGURATION
#####################################################################################

# Sets up apk repository references and updates available packages list
prep_tasks() {
    # Retrieve setup-alpine unattended settings and initialize Alpine
    wget "http://${SERVER_ADDR}/${BUILD_URL}/${SETUP_INI}" -O "${TEMP}/${SETUP_INI}"
    SSH_CONNECTION="FAKE" setup-alpine -ef "${TEMP}/${SETUP_INI}"

    sed -i "s|#http|http|g" /etc/apk/repositories
    sed -i "s|/media|#/media|g" /etc/apk/repositories
    
    apk update

}

# If LOCAL_REPOSITORY is set add to /etc/apk/repositories to APK overlay build (terminal init apk installation)
local_repository() {
    if ! [ -z "${LOCAL_REPOSITORY}" ]; then
        echo "Adding local repositories"
        echo -e "${LOCAL_REPOSITORY}/main\n$(cat /etc/apk/repositories)" > /etc/apk/repositories
        echo -e "${LOCAL_REPOSITORY}/community\n$(cat /etc/apk/repositories)" > /etc/apk/repositories
    fi

}

# Install GUI interface packages
gui_install() {
    echo "Setting up X Window system"
    setup-xorg-base
    apk add openbox xterm terminus-font font-noto
  
}

# Install Python and required packages
python_install() {
    echo "Installing Python and dependencies"
    apk add python3 python3-tkinter py3-pip
    pip install "customtkinter==5.2.2" --break-system-packages

}

# Audio support
audio_install() {
    echo "Installing audio support"
    # Packages: alsa-lib alsa-utils alsaconf pulseaudio pulseaudio-alsa
    apk add pulseaudio

}

# Retrieve client filesystem package and unpack
client_fs_install() {
    echo "Retrieving and unpacking client filesystem"
    # Get client filesystem package
    wget -qO - "http://${SERVER_ADDR}/${BUILD_URL}/${CLIENT_FS}" | tar -zoxv -C /

    # Make sure stuff thats supposed to be executable is executable
    chmod 755 /etc/local.d/*.start
    rc-update add local
    chmod 755 /etc/udhcpc/pre-bound/001-hostname
    chmod 755 /etc/X11/xinit/xinitrc.d/001-openbox-session
    chmod 755 /etc/xdg/openbox/autostart
    chmod 755 /usr/local/bin/login.py

}

# Creates apk overlay package for client to retrieve on boot
# Also installs/runs httpd server to retrieve package from set-up client to server
apkovl_package() {
    # Pack up image
    echo "Packing up APK overlay"
    # lbu include /root
    lbu include /home
    lbu include /usr/local/bin
    lbu include /usr/lib/python3.12
    lbu package "${APKOVL_FILE}"

}

# Start httpd to transfer apk overlay to boot server
busybox_httpd() {
    apk add busybox-extras
    echo "Starting httpd..."
    busybox-extras httpd -fv &
    echo "APK overlay file located at http://$(ip -f inet addr show eth0 | grep inet | cut -d ' ' -f6 | cut -d '/' -f1)/${APKOVL_FILE}"
    
}

# LETS GOOOO!

prep_tasks

gui_install

python_install

audio_install

client_fs_install

local_repository

apkovl_package

busybox_httpd

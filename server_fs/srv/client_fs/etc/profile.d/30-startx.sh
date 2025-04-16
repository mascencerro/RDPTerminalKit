#!/bin/sh

SERVER="$(cat /etc/next_server)"

wget "http://${SERVER}/alpine/client/alt_xsession.sh" -O /tmp/alt_xsession.sh

exec startx
#!/bin/sh

# Need GNU tar for this (busybox tar doesn't provide -r)
apk add tar

tar -czvf "/srv/www/alpine/build/client_fs.tar.gz" -C "/srv/client_fs" .

# Repackage changes made to client_fs files during server install
# Uncompress APK overlay tarball
gunzip /srv/www/alpine/client/thinclient.apkovl.tar.gz

# etc/next_server
tar -vf /srv/www/alpine/client/thinclient.apkovl.tar -C /srv/client_fs/ -r etc

# etc/apk/repositories
tar -vf /srv/www/alpine/client/thinclient.apkovl.tar -C /srv/client_fs/ -r usr

# Compress APK overlay tarball
gzip /srv/www/alpine/client/thinclient.apkovl.tar






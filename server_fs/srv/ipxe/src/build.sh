#!/bin/sh

#Build BIOS version (x86 but should boot into x64 environment)
make bin-i386-pcbios/undionly.kpxe EMBED=netboot.ipxe
#Build EFI version (x86)
make bin-x86_64-efi/ipxe.efi EMBED=netboot.ipxe
#Copy files to tftp root
cp bin-i386-pcbios/undionly.kpxe /var/tftpboot/
cp bin-x86_64-efi/ipxe.efi /var/tftpboot/ipxe64.efi
#The APKOVL we are using is for x64, so not building ipxe32.efi right now
#Also not building arm variants for this project
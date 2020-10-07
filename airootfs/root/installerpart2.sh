#!/bin/bash

id_system() {
	
    # Apple System Detection
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
    	modprobe -r -q efivars || true  # if MAC
    else
    	modprobe -q efivarfs            # all others
    fi
    
    # BIOS or UEFI Detection
    if [[ -d "/sys/firmware/efi/" ]]; 
	then
      # Mount efivarfs if it is not already mounted
    	if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; 
		then
    		mount -t efivarfs efivarfs /sys/firmware/efi/efivars
    	fi

    	SYSTEM="UEFI"
		
	else
    	SYSTEM="BIOS"
    fi
         
	echo $SYSTEM

}

install_lxqt(){
	pacman -S xorg xorg-xinit mesa lightdm lightdm-gtk-greeter lxqt breeze-icons \
base base-devel qt5-base qt5-declarative plasma-framework kwin fcitx fcitx-im \
kcm-fcitx kvantum-qt5 nm-connection-editor bluedevil networkmanager-qt ttf-khmer \
ttf-fira-sans ttf-droid firefox pulseaudio pulseaudio-bluetooth kwin xf86-video-qxl \
git curl ca-certificates ca-certificates-mozilla ca-certificates-utils bash readline \
glibc linux-api-headers tzdata filesystem iana-etc ncurses gcc-libs coreutils acl attr \
gmp libcap openssl perl gdbm db libxcrypt findutils p11-kit libp11-kit libtasn1 libffi \
systemd-libs libgcrypt libgpg-error lz4 xz zstd zlib krb5 e2fsprogs util-linux-libs libldap \
libsasl keyutils libssh2 libpsl libidn2 libunistring libnghttp2 expat perl-error perl-mailtools \
perl-timedate pcre2 bzip2 grep pcre shadow pam libtirpc pambase audit libcap-ng --needed --noconfirm
	systemctl enable lightdm
	git clone https://github.com/koompi/onelab.git
	tar zxf onelab/config/skel/skel.tar.gz -C /etc/skel/
	cp -r --no-target-directory onelab/config/wallpapers/. /usr/share/wallpapers/
	cp onelab/config/theme/lightdm-gtk-greeter.conf /etc/lightdm/
}

install_samba(){
	git clone https://github.com/koompi/enterprise-server.git
	cd enterprise-server
	./setup.sh
}

install_kvm(){
	pacman -S  virt-install qemu libguestfs vde2 spice bridge-utils virt-viewer ebtables iptables dmidecode dnsmasq --needed --noconfirm
	echo -e 'virtio-net\nvirtio-blk\nvirtio-scsi\nvirtio-balloon\ntun' >> /etc/modules-load.d/modules.conf
	modprobe tun
	systemctl enable libvirtd
	virsh net-autostart default
	chgrp -R kvm /var/lib/libvirt
	chmod -R 770 /var/lib/libvirt
}

install_addon(){
    ad_is_checked="false"
    gui_is_checked="false"
    kvm_is_checked="false"

    installopt=$(TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Add-on Installer ]" \
    --checklist "\nChoose additional tools you would like to readily installed with the system" 20 80 4 \
    KOOMPI_GUI "Customized KOOMPI Linux LXQT graphical user interface " OFF \
    KVM_SERVER "Bare-Metal Kernel-based Virtual Machine Server" OFF \
    AD_SERVER "SAMBA Active Directory Domain Controller + DNS NTP" OFF \
    3>&1 1>&2 2>&3)

    while read line; do
        for word in $line; do
            if [[ "$word" == \"KOOMPI_GUI\" ]];
            then
                gui_is_checked="true"
            elif [[ "$word" == \"KVM_SERVER\" ]];
            then
                kvm_is_checked="true"
            elif [[ "$word" == \"AD_SERVER\" ]];
            then
                ad_is_checked="true"
            fi
        done
    done <<< $installopt
}

uncomment_wheel(){

check="false"

while read -r line;
do
	
	if [[ "$check" == "true" ]];
	then
		echo "$line" | sed 's/^#\(.*\)/\1/' | sed 's/^ \(.*\)/\1/' >> /etc/sudoers-new
        check="false"
    else
		echo "$line" >> /etc/sudoers-new
	fi

	if [[ "$line" == "## Uncomment to allow members of group wheel to execute any command" ]];
	then
		check="true"
	fi
	
done <<< $(cat /etc/sudoers)

rm -rf /etc/sudoers
mv /etc/sudoers-new /etc/sudoers

}

install_boot(){

	system=$(id_system)

	if [[ "$system" == "UEFI" ]];
	then
		mkdir /boot/efi && 
		mount $selected_boot /boot/efi && 
		grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi && 
		grub-mkconfig -o /boot/grub/grub.cfg
	else
		parted $selected_disk set 1 bios_grub on &&
		grub-install $selected_disk && 
		grub-mkconfig -o /boot/grub/grub.cfg
	fi
}

set_lang_and_time(){

	timedatectl set-timezone Asia/Phnom_Penh
	echo LANG=en_US.UTF-8 > /etc/locale.conf
	export LANG=en_US.UTF-8

	echo "$hostname" > /etc/hostname
	echo "127.0.0.1	localhost" >> /etc/hosts
	echo "::1		localhost" >> /etc/hosts
	echo "127.0.1.1	$hostname" >> /etc/hosts

}

create_user(){

	hostname=$(TERM=ansi whiptail --clear --title "[ Hostname Dialog ]" --inputbox \
"\nPlease enter a hostname for your new linux\n" 8 80 3>&1 1>&2 2>&3)
	username=$(TERM=ansi whiptail --clear --title "[ Create a new administrator user ]" --inputbox \
"\nPlease enter an username for your new account\n" 8 80 3>&1 1>&2 2>&3)
	password=$(TERM=ansi whiptail --clear --title "[ Password Dialog ]" --passwordbox \
"\nPlease enter your password for administrator user\n" 8 80  3>&1 1>&2 2>&3)

	username=$(echo $username | tr '[:upper:]' '[:lower:]')

	useradd -mg users -G wheel,power,storage,network -s /bin/bash $username
	echo -e "$password\n$password" | passwd $username
	echo -e "$password\n$password" | passwd

}

selected_boot=$(cat selected_boot)
selected_disk=$(cat selected_disk) 

set_lang_and_time

install_boot

install_addon

if [[ "$gui_is_checked" == "true" ]];
then
	install_lxqt
fi

create_user

if [[ "$ad_is_checked" == "true" ]];
then
	install_samba
fi
if [[ "$kvm_is_checked" == "true" ]];
then
	install_kvm
	usermod -aG kvm $username
	usermod -aG kvm root
fi

uncomment_wheel

systemctl enable NetworkManager
systemctl enable sshd
systemctl disable installer.service

exit
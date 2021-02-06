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

	yay -S xorg xorg-xinit mesa lightdm lightdm-gtk-greeter lxqt breeze-icons qt5-base qt5-declarative \
	plasma-framework kwin fcitx fcitx-im kcm-fcitx kvantum-qt5 nm-connection-editor bluedevil networkmanager-qt \
	ttf-khmer ttf-fira-sans ttf-droid firefox pulseaudio pulseaudio-bluetooth chromium xf86-video-qxl accountsservice \
	konsole ksysguard tk code-headmelted-bin screen ark libreoffice-fresh nano-syntax-highlighting cmake qt5-tools \
	nm-tray-git kvantum-theme-fluent-git --needed --noconfirm
	systemctl enable lightdm
	cp lightdm-gtk-greeter.conf /etc/lightdm/
	sudo mkdir -p /etc/lightdm/lightdm.conf.d
	echo -e "[SeatDefaults]\ngreeter-hide-users=true\ngreeter-show-manual-login=true\nallow-guest=false" \
	|sudo tee -a /etc/lightdm/lightdm.conf.d/50-my-custom-config.conf
	echo -e 'include "/usr/share/nano-syntax-highlighting/*.nanorc"' |sudo tee -a /etc/nanorc
	echo -e '#!/bin/bash\nsleep 10\nkillall fcitx' | sudo tee /usr/bin/kill-fcitx
	sudo chmod +x /usr/bin/kill-fcitx
	
}

install_samba(){
	git clone https://github.com/koompi/enterprise-server.git --depth 1
	cd enterprise-server
	./setup.sh
}

install_kvm(){
	pacman -S virt-manager virt-install qemu libguestfs vde2 spice bridge-utils virt-viewer ebtables iptables dmidecode dnsmasq --needed --noconfirm
	echo -e "virtio-net\nvirtio-blk\nvirtio-scsi\nvirtio-balloon\ntun" |sudo tee -a /etc/modules-load.d/modules.conf
	modprobe tun virtio-net virtio-blk  virtio-scsi virtio-balloon
	systemctl enable libvirtd
	virsh net-autostart default
	chgrp -R kvm /var/lib/libvirt
	chmod -R 770 /var/lib/libvirt
}

install_addon(){
    ad_is_checked="false"
    gui_is_checked="false"
    kvm_is_checked="false"

    installopt=$(TERM=ansi whiptail \
	--clear \
	--backtitle "Koompi Enterprise Installer" \
	--title "[ Add-on Installer ]" \
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


install_boot(){

	system=$(id_system)

	if [[ "$system" == "UEFI" ]];
	then
		mkdir /boot/efi && 
		mount $selected_boot /boot/efi && 
		grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi 2>/dev/null && 
		grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null
	else
		parted $selected_disk set 1 bios_grub on 2>/dev/null &&
		grub-install $selected_disk 2>/dev/null&& 
		grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null
	fi
}

set_lang_and_time(){

	timedatectl set-timezone Asia/Phnom_Penh
	timedatectl set-ntp 1
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

echo -e '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/myOverrides

systemctl enable NetworkManager
systemctl enable sshd

exit
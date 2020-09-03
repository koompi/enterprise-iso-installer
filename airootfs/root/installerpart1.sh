#!/bin/bash

check_internet(){
	wget -q --spider http://google.com -T 1
	if [[ $? -eq 0 ]];
	then
		echo "true" 
	else
		echo "false"
	fi

}

print_all_disk(){

	fdiskOUTPUT=$(fdisk -l)
	rm -rf /tmp/ReadDisk
	while read -r line;
	do
	
	#find out whether the line at character 5th to 10th which is being read start with /dev/
	if [[ "${line:5:10}" == /dev/* ]] ;
	then
		
		#filter the line by looking for commas and take the pre-line number 1 and change all spaces that output into underscore and put it into file at /tmp/ReadDisk
		var=$(echo "$line" | awk -F',' '{printf $1}' | sed -e 's/ /_/g')
		echo $var >> /tmp/ReadDisk
		
	fi
	done <<< "$fdiskOUTPUT" 

}

print_all_part(){

	fdiskOUTPUT=$(fdisk -l)
	rm -rf /tmp/ReadPart
	while read -r line;
	do
	
	#find out whether the line at character 5th to 10th which is being read start with /dev/
	if [[ "$line" == $1* ]] ;
	then
		var=$(echo "$line" | sed -e 's/ /_/g')
		echo $var >> /tmp/ReadPart
	fi
	done <<< "$fdiskOUTPUT" 

}

count_line(){

	#input 1 = file for process

	temp=$(wc -l $1)
	echo $(( ${temp:0:2} ))

}

menu_list_maker(){
	
	#input 1 = count_line
	#input 2 = file for process
	#input 3 = file for result

	for (( i=1; i<=$1; i++ ))
	do
		GetLine=$(sed -n "$i{p;q}" $2)

		#make one variable to append itself everytime the output change
		genLine="$genLine $(printf "$i $GetLine \n")"

		#put the labled fdisk filter into a file at /tmp/ListDisk
		echo "$i $GetLine" >> $3
	done

	#return the appended variable outside of function
	echo $genLine

}

print_selected_disk(){

	#input 1 = file that saved the option
	#input 2 = file to be searched

	storeOpt=$(cat $1)

	while read -r line;
	do
		if [[ "$line" == $storeOpt* ]]
		then 

			storeDisk=$(echo $line | awk -F' ' '{printf $2}' | awk -F'_' '{printf $2}' | sed s/.$//)
			echo $storeDisk >> /tmp/selected_disk

		fi
	done <<< "$(cat $2)"

	echo $storeDisk
}

print_selected_part(){

	#input 1 = file that saved the option
	#input 2 = file to be searched

	storeOpt1=$(cat $1)

	while read -r line;
	do
	if [[ "$line" == $storeOpt1* ]]
	then 

		storePart=$(echo $line | awk -F' ' '{printf $2}' | sed -e 's/_/ /g')
		storePart=$(echo $storePart |awk '{printf $1}')

	fi
	done <<< "$(cat $2)"
	echo $storePart

}

choose_part(){
	while true;
	do
	TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Partition ]" --menu \
	"\nPick one suitable Partition to begin installation of $1. \n\nIt is recommended that it \
is at least $2" 30 100 \
	$countPart $partmenu 2>/tmp/temp1
	
	if (TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Partition ]" \
	--yesno "Are you sure you have choose the correct Partition to install $1? It is recommended that it \
is at least $2" 10 100);
	then
		break
	fi
	done
}

while true;
do
	internet=$(check_internet)
	if [[ "$internet" == "false" ]];
	then
		TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Welcome to Installer ]" --msgbox \
		"You are not connected to the Internet. This message will fade once you are connect to the Internet." 15 100
	else 
		TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Welcome to Installer ]" --msgbox \
		"Welcome to linux Installer. Press Enter to continue." 15 100
		break
	fi
done


print_all_disk
countDisk=$(count_line /tmp/ReadDisk)
diskmenu=$(menu_list_maker $countDisk /tmp/ReadDisk /tmp/ListDisk)


while true;
do
	TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Disk ]" --menu \
	"\nPick one suitable harddisk to begin installation process. If your disk is new, you will \
be asked to format your disk in one label type.\n\nNote: GPT is recommended." 30 100 \
	$countDisk $diskmenu 2>/tmp/temp
	
	if (TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Disk ]" \
	--yesno "Are you sure you have choose the correct disk?" 10 100);
	then 
		break
	fi
done

TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Disk ]" --msgbox \
"You will be presented with 8 options such as New, Delete, Resize, Quit, Type, Help, Write, Dump \
to choose from in order to partition your disk. \n\nNew is for partition free space into usable partition \
\n\nDelete is for remove existing partition and convert it back into free space. \n\nResize is for shrinking \
already existing partition to make some free space.\n\nWrite is for making permanent changes that you have \
done with the various option presented above.\n\n\nNote: You must have at least one 512MB BOOTLOADER partition, \
one SWAP partition, and a ROOT partition" 20 100

selected_disk=$(print_selected_disk /tmp/temp /tmp/ListDisk)

while true;
do
	cfdisk $selected_disk
	if (TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Disk ]" --yesno "Are \
you sure you have finished partitioning? You must have at least one 512MB BOOTLOADER partition, one SWAP \
partition and one ROOT partition" 10 100);
	then 
		break
	fi
done

print_all_part $selected_disk
countPart=$(count_line /tmp/ReadPart)
partmenu=$(menu_list_maker $countPart /tmp/ReadPart /tmp/ListPart)

while true;
do
	TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Linux Partition ]" --menu \
	"\nPlease Select which type of partition you would like to create. Click Done when you have finished \
Partitionning" 30 100 4 \
	"1" "Create Bootloader Partition" \
	"2" "Create Swap Partition" \
	"3" "Create Root Partition" \
	"4" "Done" 2>/tmp/temp

	case $(cat /tmp/temp) in
        "1") choose_part "BOOTLOADER" "512MB"
			 selected_boot=$(print_selected_part /tmp/temp1 /tmp/ListPart)
			 echo $selected_boot >> /tmp/selected_boot
			 mkfs.fat -F32 $selected_boot
             ;;
        "2") choose_part "SWAP" "the same as your current RAM"
			 selected_swap=$(print_selected_part /tmp/temp1 /tmp/ListPart)
			 mkswap $selected_swap
			 swapon $selected_swap
             ;; 
        "3") choose_part "ROOT" "enough for install the whole linux"
			 selected_root=$(print_selected_part /tmp/temp1 /tmp/ListPart)
			 mkfs.ext4 $selected_root
			 ;;
		  *) break
		     ;;
    esac
done

pacman -Sy
mount $selected_root /mnt

pacstrap /mnt base base-devel linux linux-firmware vim nano man-db man-pages \
networkmanager dhclient libnewt bash-completion grub efibootmgr parted openssh wget;
genfstab -U /mnt >> /mnt/etc/fstab
cp installerpart2.sh /mnt
cp /tmp/selected_disk /mnt
cp /tmp/selected_boot /mnt

arch-chroot /mnt ./installerpart2.sh
arch-chroot /mnt rm -rf selected_disk selected_boot installerpart2.sh

count_down(){
	for (( i=10; i>=1; i-- ))
	do
		TERM=ansi whiptail --backtitle "Koompi Enterprise Installer" --title "[ Koompi Enterprise Installer ]" --infobox \
	"\nPlease Remove the installation media after countdown is complete. This system will restart in $i seconds" 8 80
		sleep 1
	done

}

TERM=ansi whiptail --clear --backtitle "Koompi Enterprise Installer" --title "[ Exit Prompt ]" --menu \
"\nThe installation process has finished. What do you want to do next? In case you had any problem, you\
 may need to return to commandline" 30 100 3 \
"1" "Shutdown" \
"2" "reboot" \
"3" "Return to commandline" 2>/tmp/temp2

case $(cat /tmp/temp2) in
	"1") count_down
		 poweroff
			;;
	"2") count_down
		 reboot
			;; 
	"3") arch-chroot /mnt
			;;
		*) break
			;;
esac

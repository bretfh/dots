#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

#FIXME
#debug=1

function log_error {
  echo -e "${RED}Error: $1${NC}"
  exit 1
}

function log_info {
  echo -e "${GREEN}Info: $1${NC}"
}

function check_status {
  if [ $? -ne 0 ]; then
    log_error "$1"
  fi
}

function _debug {
    if [[ -z $debug && -z $debug_level_counter || $debug_level_counter -lt 0 ]]; then
        debug_level_counter=0
    fi
    
    debug_level_counter=$((debug_level_counter + 1))

    if [[ $debug == "on" && $debug_level -ge $debug_level_counter ]]; then
        read -p "Launching debug at level: $debug_level_counter. Enter interactive debug session? [y/n]: " choice
        case "$choice" in
            y|Y ) read -p "Press enter to enter interactive debug session (exit shell to continue)..."; artix-chroot /mnt /bin/bash;;
            n|N ) echo "Skipping interactive debug session.";;
            * ) echo "Invalid choice. Skipping interactive debug session.";;
        esac
    fi
}

# Initial prep
log_info "Starting Artix Linux installation..."
hostname="art"
services=("elogind" "dbus" "emptty" "connmand")
stty -echo; read -rp "Root password: " ROOT_PASSWORD; stty echo
echo
read -rp "User: " user; stty echo
echo
stty -echo; read -rp "User password: " user_pass; stty echo
echo
read -rp "Disk to install to: " _DISK
echo
read -rp "Clear disk partitions: ${_DISK}? This will destroy all data. [y/n]: " confirm_wipe
case "$confirm_wipe" in
    y|Y ) 
        for part in $(ls ${_DISK}* | grep -E "${_DISK}[0-9]+$"); do
            wipefs -a $part
        done
        echo "Disk partitions wiped."
        ;;
    n|N ) echo "Skipping wipe of ${_DISK} partitions.";;
    * ) echo "Invalid choice. Skipping wipe of ${_DISK} partitions.";;
esac

total_ram=$(free -g | awk '/^Mem:/{print $2}')
SWAP_SIZE=$((total_ram / 4))
read -rp "Size of swap partition in GiB [$SWAP_SIZE]: " user_swap
[ -n "$user_swap" ] && SWAP_SIZE=$user_swap

log_info "Attempting to create new partition layout"
sfdisk --wipe always "$_DISK" <<EOF
label: gpt
size=550M,type=U
size=${SWAP_SIZE}G,type=S
,,
EOF
PART1="${_DISK}1"
SWAP_PART="${_DISK}2"
ROOT_PART="${_DISK}3"
log_info "Formatting Partitions..."
mkfs.fat -F 32 -n ESP "$PART1"
check_status "Failed to format ESP partition."
mkfs.ext4 -L ROOT "$ROOT_PART"
check_status "Failed to format ROOT partition."
mkswap -L SWAP "$SWAP_PART"
check_status "Failed to format SWAP partition."
log_info "Formatted ${PART1} as FAT32, ${ROOT_PART} as ext4, ${SWAP_PART} as swap"

_debug

udevadm settle # unable to find labels after creation without this;sporadic at least
log_info "Mounting Partitions..."
check_status "Failed to mount EFI partition." || log_info "Mounted efi partition at /mnt"
mount /dev/disk/by-label/ROOT /mnt
check_status "Failed to mount ROOT partition." || log_info "Mounted ROOT partition at /mnt"
mkdir -p /mnt/boot/efi
mount /dev/disk/by-label/ESP /mnt/boot/efi
check_status "Failed to mount efi partition." || log_info "Mounted ESP? partition at /mnt"
swapon "$SWAP_PART"
check_status "Failed to create swap." || log_info "Created swap"
log_info "Enabled swap on ${SWAP_PART}"

_debug

#FIXME
base_packages="base base-devel runit elogind-runit efibootmgr grub intel-ucode connman wpa_supplicant iw git pam linux linux-firmware vim"
media_packages="pipewire pipewire-alsa pipewire-pulse pipewire-jack"
xorg_packages="xorg-server xorg-xinit"
log_info "Installing Base System Packages: ${base_packages} ${media_packages} ${xorg_packages}"
basestrap /mnt $base_packages $media_packages $xorg_packages

fstabgen -U /mnt >> /mnt/etc/fstab

_debug

export hostname
export user
export services
export ROOT_PASSWORD
export user_pass
declare -a additional_services

log_info "Performing initial setup for base system..."
cat << EOF | artix-chroot /mnt /bin/bash
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "$hostname" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
echo root:$ROOT_PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
useradd -mG wheel,dbus,audio,video,optical,storage $user
echo $user:$user_pass | chpasswd
EOF
check_status "Initial setup for system failed...somewhere?"

_debug

#DEFUNCT install artix-aur pkg for alt init builds
cat <<EOF |artix-chroot /mnt sudo -u $user /bin/bash
cd /home/$user
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
git clone https://aur.archlinux.org/emptty.git
cd emptty
sed -i 's/install-systemd/install-runit/' PKGBUILD
makepkg -si --noconfirm
EOF
check_status "failed to dl yay or emptty" || additional_services+=("emptty")

#UPDATE ME
cat <<EOF | artix-chroot /mnt /bin/bash
sed -i "s/^#*AUTOLOGIN=.*/AUTOLOGIN=true/" /etc/emptty/conf
sed -i "s/^#*DEFAULT_USER=.*/DEFAULT_USER=$user/" /etc/emptty/conf
sed -i "s/^#*DEFAULT_SESSION=.*/DEFAULT_SESSION=Stumpwm/" /etc/emptty/conf
sed -i "s/^#*DEFAULT_SESSION_ENV=.*/DEFAULT_SESSION_ENV=xorg/" /etc/emptty/conf
EOF
check_status "Unable to configure emptty"

combined_services=("${services[@]}" "${additional_services[@]}")

log_info "Enable services..."
cat << EOF | artix-chroot /mnt /bin/bash
for service in "${combined_services[@]}"; do
    if [ -d "/etc/runit/sv/$service" ]; then
        ln -s /etc/runit/sv/$service /etc/runit/runsvdir/default/
    else
        echo "Service $service does not exist."
    fi
done
EOF
check_status "Service enabling failed somwhere!"

_debug

log_info "Create $user .config"
cat <<EOF | artix-chroot /mnt /bin/bash
mkdir -p /home/$user/.config
EOF

log_info "Stage:1 for $user"
cat << 'EOF' > /mnt/home/$user/stage1.sh
#!/bin/bash
#need to install yay
#yay -S roswell nyxt picom rustup # replace yay with your AUR helper or package manager
#cd ~/dotfiles # Assuming you've cloned your dotfiles to ~/dotfiles

#stow stumpwm alacritty picom # and so on...

#UPDATE ME
cat << 'EMPTTY_CFG' > ~/.config/emptty
#!/bin/sh
Selection=true
Name=Stumpwm
Exec=/home/$USER/stumpwm.ros
Environment=xorg
xrdb -merge ~/.Xresources
. /etc/profile
. ~/.bashrc
export BROWSER=nyxt
export EDITOR=vim

picom &
pipewire &
wireplumber &
exec dbus-launch $@
EMPTTY_CFG
chmod +x ~/.config/emptty
EOF
check_status "User stage:0 script failed to create"
#chown $user:$user /mnt/home/$user/stage1.sh

log_info "completed.."

_debug

#!/bin/bash
#need to install yay
yay -S roswell nyxt picom rustup # replace yay with your AUR helper or package manager
cd ~/dotfiles # Assuming you've cloned your dotfiles to ~/dotfiles

stow stumpwm alacritty picom # and so on...

cat << 'EMPTTY_CFG' > ~/.config/emptty
#!/bin/sh
Selection=true
Name=Stumpwm
Exec=/home/$USER/stumpwm.ros
Environment=xorg
xrdb -merge ~/.Xresources
. /etc/profile
. ~/.bashrc
export BROWSER=firefox
export EDITOR=emacs

picom &
pipewire &
wireplumber &
exec dbus-launch $@
EMPTTY_CFG
chmod +x ~/.config/emptty

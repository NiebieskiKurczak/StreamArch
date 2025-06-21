#!/bin/bash
set -e

echo "=== Available Disks ==="
lsblk
echo "Enter the disk to install to (e.g., /dev/sda):"
read -r DISK

if [[ ! -b "$DISK" ]]; then
    echo "Invalid disk: $DISK"
    exit 1
fi

echo "WARNING: This will erase all data on $DISK. Type 'yes' to continue:"
read -r CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

# Partitioning (MBR for BIOS/legacy boot)
echo "Partitioning $DISK..."
parted "$DISK" --script mklabel msdos
parted "$DISK" --script mkpart primary ext4 1MiB 100%
parted "$DISK" --script set 1 boot on

# Format and mount
PART="${DISK}1"
mkfs.ext4 "$PART"
mount "$PART" /mnt

echo "Installing keys..."
pacman -Sy
pacman-key --init

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware sudo steam gamescope xorg-server xinit mesa lib32-mesa

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Ask for username and password
echo "Enter name for default user (no sudo):"
read -r USERNAME
echo "Enter password for $USERNAME:"
read -rs USERPASS

# Ask whether to enable root user
echo
echo "Do you want to enable the root user? (yes/no)"
read -r ENABLE_ROOT
if [[ "$ENABLE_ROOT" == "yes" ]]; then
    echo "Enter root password:"
    read -rs ROOTPASS
fi

# System config in chroot
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo arch > /etc/hostname

# Install GRUB
pacman -Sy --noconfirm grub
grub-install --target=i386-pc --recheck "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd

# Optionally set root password
if [[ "$ENABLE_ROOT" == "yes" ]]; then
    echo "root:$ROOTPASS" | chpasswd
fi

# Enable autologin on TTY1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOL
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --noclear %I \$TERM
EOL

# Set up .xinitrc and .bash_profile to start Gamescope + Steam
su - "$USERNAME" -c "echo 'exec gamescope -e -- steam -bigpicture' > ~/.xinitrc"
su - "$USERNAME" -c "echo '[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx' >> ~/.bash_profile"

# Enable Steam runtime fonts (some games need them)
pacman -Sy --noconfirm ttf-liberation
EOF

echo "=== Installation Complete! ==="
echo "Steam will launch in Big Picture mode automatically on boot."
echo "You can now reboot and remove the installation media."

#!/usr/bin/env bash
# Installs the macOS-style SDDM theme. Run with: sudo bash install.sh
# Undo: sudo rm -r /usr/share/sddm/themes/macos /etc/sddm.conf.d/10-macos-theme.conf
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo bash $0"; exit 1; }

rm -rf /usr/share/sddm/themes/macos
cp -r "$here" /usr/share/sddm/themes/macos
rm -f /usr/share/sddm/themes/macos/install.sh
chmod -R a+rX /usr/share/sddm/themes/macos

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-macos-theme.conf <<CONF
[Theme]
Current=macos
CONF

# Optional avatar: put a square picture at ~/.face.icon before running this.
user="${SUDO_USER:-}"
if [ -n "$user" ] && [ -f "/home/$user/.face.icon" ]; then
    mkdir -p /var/lib/AccountsService/icons
    cp "/home/$user/.face.icon" "/var/lib/AccountsService/icons/$user"
    chmod 644 "/var/lib/AccountsService/icons/$user"
    echo "Avatar installed for $user."
fi
echo "Installed. It will show at the next login screen (log out, or reboot)."

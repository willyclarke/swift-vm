#!/bin/bash
# Post-install setup for Void Linux in SwiftVM.
# Run as your regular user after first boot — uses sudo where needed.
set -e

echo "==> Syncing repositories and updating packages..."
sudo xbps-install -Su

echo "==> Installing packages..."
sudo xbps-install -y \
    sudo \
    xorg-server \
    xf86-input-libinput \
    xfce4 \
    xfce4-terminal \
    lightdm \
    lightdm-gtk3-greeter \
    alsa-utils \
    pipewire \
    wireplumber \
    alsa-pipewire \
    wireplumber-elogind \
    spice-vdagent \
    grub-utils \
    dejavu-fonts-ttf \
    clang \
    clang-tools-extra21

echo "==> Enabling system services..."
for svc in dbus elogind dhcpcd lightdm spice-vdagentd; do
    if [ ! -L "/var/service/$svc" ]; then
        sudo ln -s "/etc/sv/$svc" "/var/service/$svc"
        echo "    Enabled: $svc"
    else
        echo "    Already enabled: $svc"
    fi
done

echo "==> Configuring ALSA → PipeWire bridge..."
sudo mkdir -p /etc/alsa/conf.d
for f in 50-pipewire.conf 99-pipewire-default.conf; do
    target="/etc/alsa/conf.d/$f"
    if [ ! -L "$target" ]; then
        sudo ln -s "/usr/share/alsa/alsa.conf.d/$f" "$target"
    fi
done

echo "==> Setting up PipeWire autostart for XFCE session..."
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/pipewire.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=PipeWire
Exec=pipewire
NoDisplay=true
EOF

cat > ~/.config/autostart/wireplumber.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=WirePlumber
Exec=wireplumber
NoDisplay=true
EOF

cat > ~/.config/autostart/pipewire-pulse.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=PipeWire PulseAudio
Exec=pipewire-pulse
NoDisplay=true
EOF

echo "==> Generating en_US.UTF-8 locale..."
sudo xbps-install -y glibc-locales
sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/default/libc-locales
sudo xbps-reconfigure -f glibc-locales

echo "==> Setting up GRUB font for HiDPI / Retina display..."
sudo grub-mkfont -s 64 -o /boot/grub/fonts/large.pf2 \
    /usr/share/fonts/TTF/DejaVuSansMono.ttf

if ! grep -q "GRUB_FONT" /etc/default/grub; then
    echo 'GRUB_FONT=/boot/grub/fonts/large.pf2' | sudo tee -a /etc/default/grub
fi
sudo update-grub

echo ""
echo "==> All done! Reboot and log into XFCE."
echo ""
echo "    After first login, set audio volume once:"
echo "      wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%"
echo ""
echo "    For clipboard sharing (Mac <-> VM), spice-vdagent starts automatically."
echo "    Paste in terminal with Ctrl+Shift+V."

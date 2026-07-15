echo "This will delete ALL local files and reset this Blackbook!";
read -p "Do you want to continue? (y/n): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
echo "Powerwashing Blackbook..."

  sudo systemctl start auto-update-config.service;

  # Erase data and set up home directory again
  rm -rf ~/
  mkdir -p ~/Desktop
  mkdir -p ~/Documents
  mkdir -p ~/Downloads
  mkdir -p ~/Pictures
  mkdir -p ~/.local/share
  cp -R /etc/blackbook/config/config ~/.config
  cp /etc/blackbook/config/desktop/* ~/Desktop/

  sudo rm -r /var/lib/flatpak

  # Clear space and rebuild
  sudo nix-collect-garbage -d
  sudo nixos-rebuild switch --upgrade
  sudo nixos-rebuild list-generations

  # Add flathub and some apps
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  reboot
else
  echo "Powerwashing Cancelled!"
fi

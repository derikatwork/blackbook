echo "This will delete ALL local files and convert this machine to a Blackbook!";
read -p "Do you want to continue? (y/n): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
  echo "Installing Blackbook..."

  # Set up local files
  rm -rf ~/
  mkdir -p ~/Desktop
  mkdir -p ~/Documents
  mkdir -p ~/Downloads
  mkdir -p ~/Pictures
  mkdir -p ~/.local/share
  cp -R /etc/blackbook/config/config ~/.config
  cp /etc/blackbook/config/desktop/* ~/Desktop/

  # The rest of the install should be hands off
  # Add Blackbook config and rebuild
  sudo sed -i '/hardware-configuration\.nix/a\      /etc/blackbook/base.nix' /etc/nixos/configuration.nix

  # Set up flathub repo while we have sudo
  nix-shell -p flatpak --run 'sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo'

  sudo nixos-rebuild switch

  # Add flathub and the Zen browser
  flatpak install flathub app.zen_browser.zen -y
  flatpak install flathub org.gtk.Gtk3theme.Adwaita-dark -y

  reboot
else
  echo "Blackbook Install Cancelled!"
fi

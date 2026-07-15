echo "This will update your Blackbook and reboot";
read -p "Do you want to continue? (y/n): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
  echo "Updating Blackbook..."
  sudo systemctl stop auto-upgrade.service

  /etc/blackbook/channel.sh
  /etc/blackbook/repair.sh

  sudo systemctl start auto-update-config.service;

  # Free up space before updates
  nix-collect-garbage --delete-older-than 30d

  # get the updates
  sudo nixos-rebuild boot --upgrade

  reboot
else
  echo "Update Cancelled!"
fi

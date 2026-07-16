#!/usr/bin/env bash
#
# Blackbook desktop installer for an EXISTING graphical NixOS system.
#
# Unlike install.sh (which converts a blank minimal system into a dedicated
# Blackbook appliance and wipes the home directory), this script is
# non-destructive: it switches your machine over to the Blackbook Openbox
# desktop while leaving your files in place.
#
# It will:
#   1. Import /etc/blackbook/base.nix into /etc/nixos/configuration.nix
#      (auto-updates, Flatpak + Flathub, and the Openbox desktop).
#   2. Copy the Openbox desktop dotfiles into your home (with a backup).
#   3. Rebuild NixOS and switch you to the Openbox session.
#
# Zen Browser (Flatpak) and Thunderbird (native) give you web + email out of
# the box. Flathub is configured declaratively, so there is no manual
# remote-add step.
#
# Run as your normal, sudo-capable user - NOT as root.

set -euo pipefail

REPO=/etc/blackbook
CONF=/etc/nixos/configuration.nix

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user (it copies files into your home);"
  echo "it calls sudo itself when it needs root."
  exit 1
fi

if [ ! -d "$REPO" ]; then
  echo "The Blackbook repo was not found at $REPO."
  echo "Clone it first, then re-run this script:"
  echo
  echo "  nix-shell -p git --run \\"
  echo "    'sudo git clone https://github.com/derikatwork/blackbook.git $REPO'"
  exit 1
fi

echo "This will switch this computer to the Blackbook Openbox desktop."
echo "Your personal files are left untouched (a backup of ~/.config is made)."
read -r -p "Continue? (y/n): " answer
case "$answer" in
  [Yy]*) ;;
  *) echo "Cancelled."; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# 1. Wire base.nix into the NixOS configuration (idempotent)
# ---------------------------------------------------------------------------
echo "==> Configuring $CONF"
if grep -q '/etc/blackbook/base.nix' "$CONF"; then
  echo "    base.nix already imported - skipping"
else
  sudo cp "$CONF" "$CONF.blackbook-backup.$(date +%Y-%m-%d-%H%M%S)"
  sudo sed -i '/hardware-configuration\.nix/a\      /etc/blackbook/base.nix' "$CONF"
  echo "    imported /etc/blackbook/base.nix (backup saved alongside it)"
fi

# Warn about a setting that would clash with installed.nix rather than editing
# the user's file for them.
if grep -Eq 'allowUnfree(Predicate)?\s*=' "$CONF"; then
  echo "    NOTE: $CONF sets allowUnfree itself. Blackbook's installed.nix also"
  echo "          sets it - if the rebuild reports a conflict, remove your line."
fi

# ---------------------------------------------------------------------------
# 2. Copy the desktop dotfiles into the current user's home (non-destructive)
# ---------------------------------------------------------------------------
echo "==> Installing desktop config into ~/.config"
if [ -d "$HOME/.config" ]; then
  backup="$HOME/.config.bak.$(date +%Y-%m-%d-%H%M%S)"
  cp -a "$HOME/.config" "$backup"
  echo "    backed up existing ~/.config to $backup"
else
  mkdir -p "$HOME/.config"
fi

for d in openbox tint2 jgmenu conky dunst gtk-3.0; do
  cp -rT "$REPO/config/config/$d" "$HOME/.config/$d"
done
cp "$REPO/config/config/picom.conf" "$HOME/.config/picom.conf"

mkdir -p "$HOME/Desktop"
cp "$REPO/config/desktop/Welcome.txt" "$HOME/Desktop/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Build and switch
# ---------------------------------------------------------------------------
echo "==> Rebuilding NixOS (installs Openbox, panel, Flatpak, auto-updater...)"
sudo nixos-rebuild switch

cat <<'EOF'

============================================================
 Blackbook is installed.

 * Log out, pick the "Openbox" session at the login screen,
   and log back in (or reboot). Openbox is now the default.
 * Web + email: Thunderbird is ready now; Zen Browser
   installs itself in the background on first boot
   (Flathub is set up automatically).
 * The system auto-updates weekly - just reboot when told.

 Your previous desktop is still installed and selectable at
 the login screen. To remove it and reclaim space, delete its
 line (e.g. services.xserver.desktopManager.gnome.enable) from
 /etc/nixos/configuration.nix and run: sudo nixos-rebuild switch
============================================================
EOF

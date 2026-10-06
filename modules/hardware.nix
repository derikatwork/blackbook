# Firmware, graphics, keyboard, power, Bluetooth, and lid/power-key behavior.
{ config, ... }:

{
  # Wi-Fi, Bluetooth and GPU firmware, and AMD CPU microcode updates.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # 3D and video acceleration (Mesa radeonsi + VA-API for the Radeon R4).
  hardware.graphics.enable = true;

  # Load the GPU driver (amdgpu) early, in the initrd. Otherwise the desktop
  # can start on the firmware's basic framebuffer a moment before amdgpu
  # takes over the screen, and the desktop then loses its display (black
  # screen, or the login prompt instead of auto-login). This makes the
  # initrd about 40 MB bigger (amdgpu's firmware), which the 1 GiB boot
  # partition has room for.
  hardware.amdgpu.initrd.enable = true;

  # ---- Power --------------------------------------------------------------
  # TLP with its default settings. power-profiles-daemon would conflict with
  # it, and on this pre-Zen AMD chip it has no CPU driver (amd-pstate needs
  # Zen 2 or newer) and no firmware platform profile to switch.
  services.tlp.enable = true;
  services.power-profiles-daemon.enable = false;

  # Battery information for Waybar and other programs.
  services.upower.enable = true;

  # Closing the lid suspends (the screen locks first, see the labwc
  # autostart). The power key on the keyboard suspends instead of shutting
  # down; use the power menu to shut down.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
  };

  # ---- Bluetooth ----------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  # Provides blueman-manager and blueman-applet (started by labwc autostart).
  services.blueman.enable = true;

  # ---- Keyboard -----------------------------------------------------------
  services.keyd = {
    enable = true;
    keyboards.chromebook = {
      ids = [
        "k:0000:0000" # cros_ec keyboard
        "k:0001:0001" # AT keyboard (the built-in keyboard on most x86 Chromebooks)
      ];
      extraConfig = builtins.readFile ../files/keyd/chromebook.conf;
    };
  };
  # The keyd command itself (for `sudo keyd monitor` and `sudo keyd reload`).
  # The NixOS module only runs the daemon; it doesn't put keyd on the PATH.
  environment.systemPackages = [ config.services.keyd.package ];

  # keyd re-sends every key through its own virtual keyboard. Tell libinput
  # that keyboard is built in, so "disable touchpad while typing" still
  # works. Copied from cros-keyboard-map's local-overrides.quirks.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
    ModelTabletModeNoSuspend=1
  '';
}

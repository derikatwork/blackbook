# Sound: PipeWire with WirePlumber, plus ALSA and PulseAudio compatibility.
{ pkgs, ... }:

{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true; # lets PipeWire run with real-time priority

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;

    # The two WirePlumber settings that WeirdTreeThing/chromebook-linux-audio
    # installs on every Chromebook (conf/common/51-*.conf), written here
    # instead of copied into /etc. For Stoney Ridge, that script does nothing
    # else; the real fix is the 6.19+ kernel (see boot.nix).
    wireplumber.extraConfig = {
      # Hide the "Pro Audio" profile on Chromebook sound cards (the Stoney
      # Ridge card's name starts with "acp"), so the normal speaker and
      # headphone profiles are always used.
      "51-disable-pro-audio" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "api.alsa.card.name" = "~(sof|avs|acp).*"; } ];
            actions.update-props."api.acp.disable-pro-audio" = true;
          }
        ];
      };
      # A bigger buffer margin to avoid crackling and dropouts.
      "51-increase-headroom" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "~alsa_output.*"; } ];
            actions.update-props."api.alsa.headroom" = 2048;
          }
        ];
      };
    };
  };

  environment.systemPackages = [ pkgs.pavucontrol ];
}

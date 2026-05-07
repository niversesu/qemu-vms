{
  config,
  pkgs,
  lib,
  ...
}:

let
  robloxApk = pkgs.fetchurl {
    url = "https://pub-786f3caa6e0c467d81af67b260388ae9.r2.dev/roblox-2.718.1110.apk";
    sha256 = "006xa2cn95igv5ixg17ij3hryj9229rq7zpn4jypfd5ns3ahlacc";
  };
in

{
  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # ── VM / QEMU guest additions ─────────────────────────────────────────────
  services.qemuGuest.enable = true;
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 6144;
      cores = 8;
      diskSize = 20480;
      forwardPorts = [
        {
          host.port = 2222;
          guest.port = 22;
        }
      ];

      qemu.options = [
        "-device virtio-vga-gl,xres=1920,yres=1080"
        "-display gtk,gl=on"
        "-device virtio-serial-pci"
        "-cpu host"
        "-machine type=q35,accel=kvm"
        "-device virtio-balloon"
      ];
    };
  };

  # ── Networking ────────────────────────────────────────────────────────────
  networking = {
    hostName = "kale-vm";
    networkmanager.enable = true;
    nftables.enable = true;
  };

  # ── Locale / time ─────────────────────────────────────────────────────────
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Sound ─────────────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ── SSH ───────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.kale-vm = {
    isNormalUser = true;
    description = "Kale VM";
    extraGroups = ["wheel" "networkmanager"];
    initialPassword = "123";
  };

  security.sudo.wheelNeedsPassword = false;

  # ── Packages ──────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    neovim
    fish
    wget
    curl
    git
    wl-clipboard
    mesa
    vulkan-tools
    waypipe
    cage
    pkgs.nur.repos.ataraxiasjel.waydroid-script
  ];

  # ── Waydroid ──────────────────────────────────────────────────────────────
  virtualisation.waydroid.enable = true;

  networking.firewall.trustedInterfaces = ["waydroid0"];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # ── Waydroid first-boot setup + launch ────────────────────────────────────
  systemd.services.waydroid-setup = {
    description = "Initialize Waydroid, install Roblox, and launch it";
    wantedBy = ["multi-user.target"];
    after = ["waydroid-container.service" "network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "kale-vm";
      StateDirectory = "waydroid-setup";
      ExecStart = pkgs.writeShellScript "waydroid-setup" ''
        export PATH=${lib.makeBinPath (with pkgs; [waydroid cage])}:$PATH
        STAMP=/var/lib/waydroid-setup/done

        if [ ! -f "$STAMP" ]; then
          waydroid init -s GAPPS -f
          sleep 5
          waydroid app install ${robloxApk}
          touch "$STAMP"
        fi

        WLR_RENDERER=pixman cage -- waydroid app launch com.roblox.client
      '';
    };
  };

  # ── Autologin ─────────────────────────────────────────────────────────────
  services.getty.autologinUser = "kale-vm";

  # ── zram ──────────────────────────────────────────────────────────────────
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # ── Nix store management ──────────────────────────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1d";
  };
  nix.settings = {
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    sandbox = true;
  };

  system.stateVersion = "25.05";
}

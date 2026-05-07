{
  config,
  pkgs,
  lib,
  ...
}: {
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
  time.timeZone = "Africa/Nairobi";
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

  # ── Environment ───────────────────────────────────────────────────────────
  environment.sessionVariables = {
    WLR_RENDERER = "gles2";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

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

  # ── Autologin + Cage ──────────────────────────────────────────────────────
  services.getty.autologinUser = "kale-vm";

  programs.bash.interactiveShellInit = ''
    WLR_RENDERER=pixman cage -- waydroid app launch com.roblox.client
  '';
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


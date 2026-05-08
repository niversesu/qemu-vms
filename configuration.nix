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
  waydroidSystem = pkgs.fetchurl {
    url = "https://pub-786f3caa6e0c467d81af67b260388ae9.r2.dev/system.img";
    sha256 = "sha256-B9SthRdo2s7I3K5jOla41lQfE9vevjwx1ver/sld5fc=";
  };
  waydroidVendor = pkgs.fetchurl {
    url = "https://pub-786f3caa6e0c467d81af67b260388ae9.r2.dev/vendor.img";
    sha256 = "sha256-Xtr7kmeMWr7HyEA8aHPOHeWDAJpXpstt5E2Z+bP1wHA=";
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
    extraGroups = ["wheel" "networkmanager" "video" "input"];
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

  # ── Waydroid images (declarative, via environment.etc) ────────────────────
  environment.etc."waydroid-extra/images/system.img".source = waydroidSystem;
  environment.etc."waydroid-extra/images/vendor.img".source = waydroidVendor;

  # ── Waydroid ──────────────────────────────────────────────────────────────
  virtualisation.waydroid.enable = true;

  networking.firewall.trustedInterfaces = ["waydroid0"];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # ── Waydroid init (user, once) ────────────────────────────────────────────
  systemd.services.waydroid-init = {
    description = "Initialize Waydroid and install Roblox";
    wantedBy = ["multi-user.target"];
    after = ["waydroid-container.service"];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "kale-vm";
      Environment = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus";
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = pkgs.writeShellScript "waydroid-init" ''
        export PATH=${lib.makeBinPath (with pkgs; [waydroid])}:$PATH
        STAMP=/home/kale-vm/.waydroid-setup-done
        if [ -f "$STAMP" ]; then exit 0; fi

        echo "Waiting for Waydroid to leave STOPPED state..."
        while true; do
          STATUS=$(waydroid status 2>&1)
          echo "Status: $STATUS"
          if echo "$STATUS" | grep -qi "STOPPED"; then
            sleep 5
            continue
          fi
          echo "Waydroid is up, proceeding."
          break
        done

        echo "Running app install..."
        OUTPUT=$(waydroid app install ${robloxApk} 2>&1)
        echo "Install output: $OUTPUT"

        if [ -n "$OUTPUT" ]; then
          echo "Install produced output, something went wrong, failing so systemd restarts us."
          exit 1
        fi

        echo "Install succeeded, stamping."
        touch "$STAMP"
        exit 0
      '';
    };
  };

  # ── Autologin + launch on tty1 ────────────────────────────────────────────
  services.getty.autologinUser = "kale-vm";

  programs.bash.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      export PATH=${lib.makeBinPath (with pkgs; [waydroid cage])}:$PATH
      export XDG_RUNTIME_DIR=/run/user/$(id -u)
      waydroid session start &
      sleep 3
      WLR_RENDERER=pixman cage -- waydroid show-full-ui
    fi
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

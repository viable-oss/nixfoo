# It's a setup for my backup.
{ config, options, lib, pkgs, ... }:

let
  cfg = config.tasks.backup-archive;

  borgJobCommonSetting = { patterns ? [ ], passCommand }: {
    compression = "zstd,12";
    dateFormat = "+%F-%H-%M-%S-%z";
    doInit = false;
    encryption = {
      inherit passCommand;
      mode = "repokey-blake2";
    };
    extraCreateArgs = lib.concatStringsSep " "
      (builtins.map (patternFile: "--patterns-from ${patternFile}") patterns);
    extraInitArgs = "--make-parent-dirs";

    # We're emptying them since we're specifying them all through the patterns file.
    paths = [ ];

    persistentTimer = true;
    preHook = ''
      extraCreateArgs="$extraCreateArgs --exclude-if-present .nobackup"
      extraCreateArgs="$extraCreateArgs --stats"
    '';
    prune = {
      keep = {
        within = "1d";
        hourly = 8;
        daily = 30;
        weekly = 4;
        monthly = 6;
        yearly = 3;
      };
    };
  };

  hetzner-boxes-user = "u332477";
  hetzner-boxes-server = "${hetzner-boxes-user}.your-storagebox.de";
in
{
  options.tasks.backup-archive.enable =
    lib.mkEnableOption "backup setup with BorgBackup";

  config = lib.mkIf cfg.enable {
    sops.secrets =
      let
        getKey = key: {
          inherit key;
          sopsFile = lib.getSecret "backup-archive.yaml";
        };
        getSecrets = secrets:
          lib.mapAttrs'
            (key: config:
              lib.nameValuePair
                "borg-backup/${key}"
                ((getKey key) // config))
            secrets;
      in
      getSecrets {
        "borg-patterns/home" = { };
        "borg-patterns/etc" = { };
        "borg-patterns/keys" = { };
        "borg-patterns/remote-backup" = { };
        "borg-repos/archive/password" = { };
        "borg-repos/external-drive/password" = { };
        "borg-repos/hetzner-box/password" = { };
        "ssh-key" = { };
      };

    profiles.filesystem = {
      archive.enable = true;
      external-hdd.enable = true;
    };

    services.borgbackup.jobs = {
      local-archive = borgJobCommonSetting
        {
          patterns = with config.sops; [
            secrets."borg-backup/borg-patterns/home".path
            secrets."borg-backup/borg-patterns/etc".path
            secrets."borg-backup/borg-patterns/keys".path
          ];
          passCommand = "cat ${config.sops.secrets."borg-backup/borg-repos/archive/password".path}";
        } // {
        removableDevice = true;
        repo = "/mnt/archives/backups";
        startAt = "daily";
      };

      local-external-drive = borgJobCommonSetting
        {
          patterns = with config.sops; [
            secrets."borg-backup/borg-patterns/home".path
            secrets."borg-backup/borg-patterns/etc".path
            secrets."borg-backup/borg-patterns/keys".path
          ];
          passCommand = "cat ${config.sops.secrets."borg-backup/borg-repos/external-drive/password".path}";
        } // {
        removableDevice = true;
        repo = "/mnt/external-storage/backups";
        startAt = "daily";
      };

      remote-backup-hetzner-box = borgJobCommonSetting
        {
          patterns = with config.sops; [
            secrets."borg-backup/borg-patterns/remote-backup".path
          ];
          passCommand = "cat ${config.sops.secrets."borg-backup/borg-repos/hetzner-box/password".path}";
        } // {
        doInit = true;
        repo = "ssh://${hetzner-boxes-user}@${hetzner-boxes-server}:23/./borg/desktop/ni";
        startAt = "daily";
        environment.BORG_RSH = "ssh -i ${config.sops.secrets."borg-backup/ssh-key".path}";
      };
    };

    programs.ssh.extraConfig = ''
      Host ${hetzner-boxes-server}
       IdentityFile ${config.sops.secrets."borg-backup/ssh-key".path}
    '';
  };
}

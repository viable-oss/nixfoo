{ name, config, lib, session, utils, ... }:

let
  optionalSystemdUnitOption = type: systemdModuleAttribute:
    lib.mkOption {
      description = ''
        An optional systemd ${type} configuration to be generated.

        :::{.note}
        This has the same options as
        {option}`systemd.user.${systemdModuleAttribute}.<name>` but without
        certain options from stage 2 counterparts such as `reloadTriggers` and
        `restartTriggers`.
        :::
      '';
      default = null;
    };
in
{
  options = {
    description = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "One-sentence description of the component.";
      example = "Desktop widgets";
    };

    # Most of the systemd config types are trying to eliminate as much of the
    # NixOS systemd extensions as much as possible. For more details, see
    # `config` attribute of the `sessionType`.
    serviceUnit = lib.mkOption {
      type =
        let
          inherit (utils.systemdUtils.lib) unitConfig serviceConfig;
          inherit (utils.systemdUtils.unitOptions) commonUnitOptions serviceOptions;
        in
        lib.types.submodule [
          commonUnitOptions
          serviceOptions
          serviceConfig
          unitConfig
        ];
      description = ''
        systemd service configuration to be generated. This should be
        configured if the session is managed by systemd.

        :::{.note}
        This has the same options as {option}`systemd.user.services.<name>`
        but without certain options from stage 2 counterparts such as
        `reloadTriggers` and `restartTriggers`.

        By default, this module sets the service unit as part of the respective
        target unit (i.e., `PartOf=$COMPONENTID.target`). On a typical case,
        you shouldn't mess with much of the dependency ordering with the
        service unit. You should configure `targetUnit` for that instead.
        :::
      '';
    };

    targetUnit = lib.mkOption {
      type =
        let
          inherit (utils.systemdUtils.lib) unitConfig;
          inherit (utils.systemdUtils.unitOptions) commonUnitOptions;
        in
        lib.types.submodule [
          commonUnitOptions
          unitConfig
        ];
      description = ''
        systemd target configuration to be generated. This is generated by
        default alongside the service where it is configured to be a part of
        the target unit.

        :::{.note}
        This has the same options as {option}`systemd.user.targets.<name>`
        but without certain options from stage 2 counterparts such as
        `reloadTriggers` and `restartTriggers`.
        :::
      '';
    };

    timerUnit = optionalSystemdUnitOption "timer" "timers" // {
      type =
        let
          inherit (utils.systemdUtils.unitOptions) timerOptions commonUnitOptions;
          inherit (utils.systemdUtils.lib) unitConfig;
        in
        with lib.types; nullOr (submodule [
          commonUnitOptions
          timerOptions
          unitConfig
        ]);
    };

    socketUnit = optionalSystemdUnitOption "socket" "sockets" // {
      type =
        let
          inherit (utils.systemdUtils.unitOptions) socketOptions commonUnitOptions;
          inherit (utils.systemdUtils.lib) unitConfig;
        in
        with lib.types; nullOr (submodule [
          commonUnitOptions
          socketOptions
          unitConfig
        ]);
    };

    pathUnit = optionalSystemdUnitOption "path" "paths" // {
      type =
        let
          inherit (utils.systemdUtils.unitOptions) pathOptions commonUnitOptions;
          inherit (utils.systemdUtils.lib) unitConfig;
        in
        with lib.types; nullOr (submodule [
          commonUnitOptions
          pathOptions
          unitConfig
        ]);
    };

    id = lib.mkOption {
      type = lib.types.str;
      description = ''
        The identifier of the component used in generating filenames for its
        `.desktop` files and as part of systemd unit names.
      '';
      default = "${session.name}.${name}";
      defaultText = "\${session-name}.\${name}";
      readOnly = true;
    };
  };

  config = {
    /*
      Setting some recommendation and requirements for sessiond components.
      Note there are the missing directives that COULD include some sane
      defaults here.

      * The `Unit.OnFailure=` and `Unit.OnFailureJobMode=` directives. Since
      different components don't have the same priority and don't handle
      failures the same way, we didn't set it here. This is on the user to
      know how different desktop components interact with each other
      especially if one of them failed.

      * Even if we have a way to limit starting desktop components with
      `systemd-xdg-autostart-condition`, using `Service.ExecCondition=` would
      severely limit possible reuse of desktop components with other
      NixOS-module-generated gnome-session sessions so we're not bothering with
      those.

      * Most sandboxing options. Aside from the fact we're dealing with a
      systemd user unit, much of them are unnecessary and rarely needed (if
      ever like `Service.PrivateTmp=`?) so we didn't set such defaults here.
    */
    serviceUnit = {
      description = lib.mkDefault config.description;

      # The typical workflow for service units to have them set as part of
      # the respective target unit.
      requisite = [ "${config.id}.target" ];
      before = [ "${config.id}.target" ];
      partOf = [ "${config.id}.target" ];

      # Some sane service configuration for a desktop component.
      serviceConfig = {
        Slice = lib.mkDefault "session.slice";
        Restart = lib.mkDefault "on-failure";
        TimeoutStopSec = lib.mkDefault 5;

        # We'll assume most of the components are reasonably required so we'll
        # set a reasonable middle-in-the-ground value for this one. The user
        # should have the responsibility passing judgement for what is best for
        # this.
        OOMScoreAdjust = lib.mkDefault -500;
      };

      startLimitBurst = lib.mkDefault 3;
      startLimitIntervalSec = lib.mkDefault 15;

      unitConfig = {
        # We leave those up to the target units to start the services.
        RefuseManualStart = lib.mkDefault true;
        RefuseManualStop = lib.mkDefault true;
      };
    };

    /*
      Take note the session target unit already has `Wants=$COMPONENT.target`
      so no need to set dependency ordering directives here.

      And another thing, we also didn't set any dependency ordering directives
      to any of sessiond-specific systemd units (if there's any). It is more
      likely that the user will design their own desktop session with full
      control so this would be better set as empty for less confusion.
    */
    targetUnit = {
      wants = [ "${config.id}.service" ];
      description = lib.mkDefault config.description;
    };
  };
}

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  dmsPackage = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
  dmsIPC = "${dmsPackage}/bin/dms ipc call";

  nordTheme = pkgs.writeText "dms-nord.json" (
    builtins.toJSON {
      dark = {
        name = "Nord Dark";
        primary = "#88c0d0";
        primaryText = "#2e3440";
        primaryContainer = "#5e81ac";
        secondary = "#81a1c1";
        surface = "#2e3440";
        surfaceText = "#eceff4";
        surfaceVariant = "#3b4252";
        surfaceVariantText = "#d8dee9";
        surfaceTint = "#88c0d0";
        background = "#2e3440";
        backgroundText = "#eceff4";
        outline = "#4c566a";
        surfaceContainerLowest = "#242933";
        surfaceContainerLow = "#2e3440";
        surfaceContainer = "#3b4252";
        surfaceContainerHigh = "#434c5e";
        surfaceContainerHighest = "#4c566a";
        error = "#bf616a";
        warning = "#ebcb8b";
        info = "#88c0d0";
        matugen_type = "scheme-tonal-spot";
      };
      light = {
        name = "Nord Light";
        primary = "#5e81ac";
        primaryText = "#eceff4";
        primaryContainer = "#81a1c1";
        secondary = "#8fbcbb";
        surface = "#eceff4";
        surfaceText = "#2e3440";
        surfaceVariant = "#e5e9f0";
        surfaceVariantText = "#3b4252";
        surfaceTint = "#5e81ac";
        background = "#eceff4";
        backgroundText = "#2e3440";
        outline = "#4c566a";
        surfaceContainerLowest = "#ffffff";
        surfaceContainerLow = "#eceff4";
        surfaceContainer = "#e5e9f0";
        surfaceContainerHigh = "#d8dee9";
        surfaceContainerHighest = "#c8d0dc";
        error = "#bf616a";
        warning = "#d08770";
        info = "#5e81ac";
        matugen_type = "scheme-tonal-spot";
      };
    }
  );

  wallpaper = "${config.home.homeDirectory}/Pictures/wallpapers/default-background.jpg";
in
{
  # DMS can start while Home Manager is still linking settings.json; create the
  # completion marker first so its welcome wizard never opens during login.
  home.activation.disableDmsWelcome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m0644 /dev/null "${config.home.homeDirectory}/.config/DankMaterialShell/.firstlaunch"
  '';
  programs.dank-material-shell = {
    enable = true;
    package = dmsPackage;
    systemd.enable = true;

    enableSystemMonitoring = true;
    enableDynamicTheming = false;

    settings = {
      configVersion = 12;
      currentThemeName = "custom";
      currentThemeCategory = "custom";
      customThemeFile = "${nordTheme}";
      clockFormat = "12h";
      padHours12Hour = false;
      useAutoLocation = true;
      weatherEnabled = true;
      cornerRadius = 0;
      popupTransparency = 0.65;
      barElevationEnabled = false;
      m3ElevationEnabled = false;
      notificationCompactMode = true;
      notificationFocusedMonitor = true;
      notificationHistoryEnabled = true;
      showSeconds = false;
      audioWheelScrollAmount = 1;
      showWorkspaceIndex = true;

      barConfigs = [
        {
          id = "default";
          name = "Main Bar";
          enabled = true;
          position = 0;
          screenPreferences = [ "all" ];
          showOnLastDisplay = true;
          leftWidgets = [
            "launcherButton"
            "workspaceSwitcher"
            "separator"
            "network"
            "cpuUsage"
            "memUsage"
          ];
          centerWidgets = [ "clock" ];
          rightWidgets = [
            "privacyIndicator"
            "idleInhibitor"
            "music"
            "notificationButton"
            "clipboard"
            "bluetooth"
            "audio"
            "brightness"
            "battery"
            "systemTray"
            "controlCenterButton"
            "powerMenuButton"
          ];
          spacing = 0;
          innerPadding = 0;
          bottomGap = 0;
          transparency = 0.65;
          widgetTransparency = 0.0;
          squareCorners = true;
          noBackground = true;
          maximizeWidgetIcons = false;
          maximizeWidgetText = false;
          removeWidgetPadding = true;
          widgetPadding = 2;
          gothCornersEnabled = false;
          gothCornerRadiusOverride = false;
          gothCornerRadiusValue = 12;
          borderEnabled = false;
          borderColor = "surfaceText";
          borderOpacity = 1.0;
          borderThickness = 1;
          widgetOutlineEnabled = false;
          widgetOutlineColor = "primary";
          widgetOutlineOpacity = 1.0;
          widgetOutlineThickness = 1;
          fontScale = 0.9;
          iconScale = 0.85;
          autoHide = false;
          autoHideStrict = false;
          autoHideDelay = 250;
          showOnWindowsOpen = false;
          openOnOverview = false;
          visible = true;
          popupGapsAuto = true;
          popupGapsManual = 4;
          maximizeDetection = true;
          useOverlayLayer = false;
          scrollEnabled = true;
          scrollXBehavior = "column";
          scrollYBehavior = "workspace";
          shadowIntensity = 0;
          shadowOpacity = 60;
          shadowColorMode = "default";
          shadowCustomColor = "#000000";
          clickThrough = false;
          hoverPopouts = false;
          hoverPopoutDelay = 150;
        }
      ];

      acLockTimeout = 300;
      acPostLockMonitorTimeout = 10;
      batteryLockTimeout = 300;
      batteryPostLockMonitorTimeout = 10;
      lockBeforeSuspend = true;
      loginctlLockIntegration = true;
      fadeToLockEnabled = true;
      fadeToLockGracePeriod = 5;
      fadeToDpmsEnabled = true;
      fadeToDpmsGracePeriod = 5;
    };

    session = {
      configVersion = 3;
      isLightMode = false;
      wallpaperPath = wallpaper;
      wallpaperTransition = "fade";
      wallpaperCyclingEnabled = true;
      wallpaperCyclingMode = "interval";
      wallpaperCyclingInterval = 1800;
      nightModeEnabled = true;
      nightModeAutoEnabled = true;
      nightModeAutoMode = "location";
      nightModeUseIPLocation = true;
    };
  };

  wayland.windowManager.sway.config.keybindings = lib.mkOptionDefault {
    "Mod4+Shift+x" = "exec ${dmsIPC} lock lock";
    "Mod4+d" = "exec ${dmsIPC} spotlight toggle";
  };

  programs.niri.settings.binds = {
    "Mod+D".action.spawn = [
      "${dmsPackage}/bin/dms"
      "ipc"
      "call"
      "spotlight"
      "toggle"
    ];
    "Mod+Shift+X".action.spawn = [
      "${dmsPackage}/bin/dms"
      "ipc"
      "call"
      "lock"
      "lock"
    ];
  };
}

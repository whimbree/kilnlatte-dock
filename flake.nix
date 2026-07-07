{
  # Phase 0 of docs/PORTING_PLAN.md: a reproducible Qt6/KF6 toolchain so the
  # port has something to configure against from the first commit. Phase 11
  # extends this with packages.default, overlays.default, nixosModules.default.
  description = "latte-dock Plasma 6/Qt6 port - development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Development happens on x86_64 NixOS; widen when someone needs it.
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems
        (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
            kdePackages.extra-cmake-modules
          ];

          buildInputs = (with pkgs.kdePackages; [
            # Qt
            qtbase
            qtdeclarative
            qtwayland

            # Plasma (de-umbrella'd from KF5 Plasma/PlasmaQuick, see Phase 1/3)
            libplasma
            plasma-activities
            plasma-activities-stats
            plasma-workspace # LibTaskManager, LibNotificationManager
            libksysguard
            kwayland
            plasma-wayland-protocols
            layer-shell-qt

            # KDE Frameworks 6
            karchive
            kcmutils
            kconfig
            kcoreaddons
            kcrash
            kdbusaddons
            kdeclarative
            kglobalaccel
            kguiaddons
            ki18n
            kiconthemes
            kio
            kirigami
            knewstuff
            knotifications
            kpackage
            ksvg
            kwindowsystem # includes KX11Extras for the best-effort X11 path
            kxmlgui
          ]) ++ (with pkgs; [
            wayland

            # Best-effort X11 path (HAVE_X11): XCB RANDR/SHAPE/EVENT + SM per
            # the top-level CMakeLists. Qt5X11Extras is gone in Qt6; native
            # handles come from QNativeInterface::QX11Application instead.
            libx11
            libsm
            libice
            libxcb
            libxcb-util
            libxrandr
          ]);

          # Building works from this shell as-is. Running the built binary
          # needs the usual Qt env wrapping (plugin/QML paths); revisit when
          # the first runnable milestone lands (end of Phase 5).
        };
      });
    };
}

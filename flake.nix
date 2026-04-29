{
  description = "Nix flake for PandoraLauncher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
      releaseVersion = "5.0.2";
      releaseSha256 = "sha256-gvFRKSLbf2GsmMw6rdPxj4o9JTrnosLnJUEZP8mUjGY=";

      minecraftLibs =
        pkgs: with pkgs; [
          stdenv.cc.cc
          zlib
          libuuid
          at-spi2-atk
          mesa
          vulkan-loader
          libGL
          flite
          libpulseaudio
          alsa-lib
          libogg
          libvorbis
          libopus
          openssl
          curl
          expat
          nss
          icu
          fuse3
          glib
          libudev0-shim
          wayland
          libxkbcommon
          pciutils
          libxrender
          libxtst
          libx11
          libxcursor
          libxrandr
          libxext
          libxxf86vm
          libxi
          libxinerama
          libxcomposite
          libxdamage
          libxfixes
          libxcb
          flac
          freeglut
          libjpeg
          libpng
          libsamplerate
          libmikmod
          libtheora
          libtiff
          pixman
          speex
          SDL2
        ];

      pandora-portable = pkgs.stdenv.mkDerivation {
        pname = "PandoraLauncher";
        version = releaseVersion;

        src = pkgs.fetchurl {
          url = "https://github.com/Moulberry/PandoraLauncher/releases/download/v${releaseVersion}/PandoraLauncher-Linux-x86_64-Portable";
          sha256 = releaseSha256;
        };
        dontUnpack = true;

        buildInputs = (
          with pkgs;
          [
            makeWrapper
            autoPatchelfHook

            libgcc
            openssl
            libxkbcommon
            libxcb
            libseccomp
          ]
        );
        installPhase = ''
          runHook preInstall

          mkdir -p $out/libexec
          install $src $out/libexec/PandoraLauncher

          runHook postInstall

          makeWrapper $out/libexec/PandoraLauncher $out/bin/PandoraLauncher-unwrapped \
            --prefix LD_LIBRARY_PATH : ${
              pkgs.lib.makeLibraryPath (
                with pkgs;
                [
                  # PandoraLauncher libs
                  wayland
                  vulkan-loader

                  # FIXME: Any of these should allow use to open URLs, but they don't.
                  # https://github.com/zed-industries/zed/blob/d7bce5468521791c40b2f4641c23c3ce878bfd70/crates/gpui/src/platform/linux/wayland/client.rs#L789
                  # There's a demo of `ashpd` & using the "Open URI" demo literally just doesn't work.
                  # Even with the below packages it just doesn't work.
                  # xgd-open does work for me (Which the `open` crate uses, but in the linked code it literally just doesn't get to execute it.)
                  # NOTE: I have resorted to just building PandoraLauncher & just insert a println! with the login URL:
                  # PandoraLauncher/crates/backend/src/backend.rs#L410
                  dbus
                  xdg-utils
                  xdg-desktop-portal

                  # Java runtimes
                  # NOTE: PandoraLauncher doesn't have a way to automatically have java runtimes detected yet. So you'll just have to manually select the /nix/store runtimes.
                  # NOTE: PrismLauncher has a command-line argument for java runtimes to override the autodetect, & hopefully PandoraLauncher does the same.
                  jdk17
                  jdk21
                  zulu17
                  zulu21
                  graalvmPackages.graalvm-ce
                  semeru-bin-17
                  semeru-bin # 21

                  # OpenGL
                  glfw3-minecraft
                  libGL
                  libx11
                  libxcursor
                  libxext
                  libxrandr
                  libxxf86vm

                  # vulkan-loader # For VulkanMod. Already included because PandoraLauncher uses vulkan.

                  # OpenAL
                  openal
                  alsa-lib
                  libjack2
                  libpulseaudio
                  pipewire

                  openssl

                  udev

                  gamemode.lib # Gamemode support
                  libusb1 # Controller support
                ]
              )
            }

            mkdir -p $out/share/applications
            cp ${./PandoraLauncher.desktop} $out/share/applications/PandoraLauncher.desktop
            mkdir -p $out/share/icons/hicolor/scalable/apps
            cp ${./PandoraLauncher.svg} $out/share/icons/hicolor/scalable/apps/PandoraLauncher.svg
        '';

        meta = {
          name = "PandoraLauncher-${releaseVersion}";
          description = "Pandora is a modern Minecraft launcher that balances ease-of-use with powerful instance management features";
          homepage = "https://pandora.moulberry.com/";
          license = pkgs.lib.licenses.mit;
          mainProgram = "PandoraLauncher-unwrapped";
          platforms = [ "x86_64-linux" ];
        };
      };

      pandora-fhs = pkgs.buildFHSEnv {
        name = "PandoraLauncher";
        targetPkgs = minecraftLibs;
        runScript = "${pandora-portable}/bin/PandoraLauncher-unwrapped";
      };
    in
    {
      packages."x86_64-linux".default = pkgs.symlinkJoin {
        name = "pandora-launcher";
        paths = [
          pandora-fhs
          pandora-portable
        ];

        meta = with pkgs.lib; {
          description = "Modern Minecraft launcher (FHS Wrapped)";
          homepage = "https://github.com/Moulberry/PandoraLauncher";
          license = licenses.mit;
          mainProgram = "PandoraLauncher";
        };
      };
    };
}

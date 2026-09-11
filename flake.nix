{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/1758b488e6a06d12975ba6d7ab25cb6419329e3c";
      flake = false;
    };
    nixpkgs-new.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs-new, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs-new = import nixpkgs-new {
        inherit system;
      };

      patched-nixpkgs = pkgs-new.applyPatches {
          name = "patched-nixpkgs";
          src = nixpkgs;
          patches = [ ./mirrors-diff.patch ];
      };

      # create a patched version of old nixpkgs using current nixpkgs for static curl and stdenv
      curl-patched-nixpkgs = nixpkgs-new.legacyPackages.${system}.stdenv.mkDerivation {
        name = "curl-patched-nixpkgs";
        src = patched-nixpkgs;
        phases = [
          "unpackPhase"
          "installPhase"
        ];
        installPhase =
          let
            curlStatic = pkgs-new.lib.getExe pkgs-new.pkgsStatic.curl;
          in
          ''
            cp -r . $out
            bzip2 -c ${curlStatic} > $out/pkgs/stdenv/linux/bootstrap/i686/curl.bz2
          '';
      };

      pkgs = import curl-patched-nixpkgs {
        inherit system;
        config.packageOverrides = self: {
          curl = pkgs-new.pkgsStatic.curl;
        };
      };

      libs = (with pkgs; [
        gtkLibs.gtk
        gtkLibs.glib
        xlibs.libXtst
        ]
      );
    in
    {
      packages.${system}.default = pkgs-new.stdenv.mkDerivation {
        name = "oneswarm";
        buildInputs = with pkgs; [
          jdk
          swt
          ant
        ] ++ libs;

        buildPhase = ''
          ant
        '';

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/share/oneswarm
          
          # Recreate the expected source structure for the web files
          mkdir -p $out/share/oneswarm/oneswarm_gwt_ui
          cp -r oneswarm_gwt_ui/war $out/share/oneswarm/oneswarm_gwt_ui/

          cp OneSwarm.jar $out/share/oneswarm/
          cp build/swt/swt-gtk-linux-x86_64.jar $out/share/oneswarm/swt.jar
          
          # If gwt-bin is needed, keep it in the working directory
          cp -r gwt-bin $out/share/oneswarm/ || true

          # Create launcher script
          cat > $out/bin/oneswarm <<EOF
          #!/bin/sh
          export LC_ALL="C"
          export LOCALE_ARCHIVE=""
          export LD_LIBRARY_PATH="${
            pkgs-new.lib.makeLibraryPath libs
          }:\$LD_LIBRARY_PATH"
          
          # CHANGE: Execute from the directory containing the files
          cd $out/share/oneswarm

          echo $PWD

          exec ${pkgs.jdk}/bin/java \
            -cp "OneSwarm.jar:swt.jar:oneswarm_gwt_ui/war" \
            org.gudy.azureus2.ui.swt.Main "\$@"
          EOF

          chmod +x $out/bin/oneswarm
        '';

        src = ./.;
      };
    };
}

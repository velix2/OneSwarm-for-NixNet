{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixnet.url = "github:birneee/nixnet";
    oneswarm.url = "path:../app";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixnet.supportedSystems;
      perSystem =
        { pkgs, inputs', ... }:
        let
          nixnet = inputs'.nixnet.legacyPackages;
          oneswarm = inputs'.oneswarm.packages.default;
          config = {
            workDir = null;
            shareWayland = true;
            arp = false;
            arpPrefill = true;
            nodePackages = with pkgs; [
              oneswarm
              coreutils
              xwayland-satellite
              fontconfig
            ];
            nodes = {
              alice = {
                shareWayland = true;
                networking.interfaces.veth0.ipv4.addresses = [
                  {
                    address = "10.0.0.1";
                    prefixLength = 24;
                  }
                ];
                scripts.main = {
                  exec = ''
                    cp ${./contents/file.txt} file.txt

                    export DISPLAY=:0
                    export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"

                    xwayland-satellite > /dev/null 2>&1 &
                    oneswarm > /dev/null 2>&1 
                  '';
                };
              };
              bob = {
                packages = [ pkgs.diffutils ];
                shareWayland = true;
                networking.interfaces.veth0.ipv4.addresses = [
                  {
                    address = "10.0.0.2";
                    prefixLength = 24;
                  }
                ];
                scripts.main = {
                  exec = ''
                    checkSuccess() {
                      cp -r /root/.oneswarm /pwd

                      # check if contents of "/root/OneSwarm Downloads/file.txt" is equal to the contents of "file.txt"
                      if ! cmp -s "/root/OneSwarm Downloads/file.txt" ${./contents/file.txt}; then
                        echo "Error: file.txt does not match the original file."
                        exit 1
                      fi
                      echo "Success: File received."
                      exit 0
                    }

                    trap checkSuccess EXIT
                    trap 'exit 1' INT TERM

                    cp ${./contents/file.txt.torrent} file.txt.torrent

                    export DISPLAY=:0
                    export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"

                    xwayland-satellite > /dev/null 2>&1 &
                    oneswarm > /dev/null 2>&1 
                  '';
                  await = true;
                  foreground = true;
                };
              };
            };
            veths.veth0 = {
              a.node = "alice";
              b.node = "bob";
            };
          };
        in
        {
          packages.default = nixnet.mkExperiment config;
          packages.mermaid = nixnet.mkMermaid config;
          packages.mermaid-svg = nixnet.mkMermaidSvg config;
        };
    };
}

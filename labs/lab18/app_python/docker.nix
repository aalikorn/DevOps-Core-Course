{ pkgs ? import <nixpkgs> {} }:

let
  app = import ./default.nix { inherit pkgs; };
in
pkgs.dockerTools.buildLayeredImage {
  name = "devops-info-service-nix";
  tag = "1.0.0";

  contents = [ app pkgs.coreutils pkgs.bash ];

  config = {
    Cmd = [ "${app}/bin/devops-info-service" ];
    ExposedPorts = {
      "5001/tcp" = {};
    };
    Env = [
      "PORT=5001"
      "HOST=0.0.0.0"
    ];
  };

  created = "1970-01-01T00:00:01Z";
}

{
  description = "DevOps Info Service - Reproducible Build with Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        default = import ./default.nix { inherit pkgs; };
        dockerImage = import ./docker.nix { inherit pkgs; };
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          python313
          python313Packages.fastapi
          python313Packages.uvicorn
          python313Packages.python-json-logger
          python313Packages.prometheus-client
        ];

        shellHook = ''
          echo "DevOps Info Service - Development Environment"
          echo "Python version: $(python --version)"
          echo ""
          echo "Available commands:"
          echo "  python app.py          - Run the application"
          echo "  nix build              - Build with Nix"
          echo "  nix build .#dockerImage - Build Docker image"
        '';
      };
    };
}

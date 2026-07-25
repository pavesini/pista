{
  description = "Node.js development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs_22          # provides node, npm and npx
            nodePackages.prettier
            nodePackages.eslint
            nodePackages.typescript
            nodePackages.typescript-language-server
          ];
          # Keeps `npm install -g` out of the read-only Nix store
          NPM_CONFIG_PREFIX = "./.npm-global";
        };
      });
}

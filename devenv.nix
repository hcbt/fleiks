{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    gh
    nix
    curl
    nixfmt
  ];
}

{ pkgs, ... }:

{
  # Every tool the declared test command (`devenv shell scripts/test`) needs.
  # jj is deliberately absent: the tests run the host's jj against this
  # checkout, and a newer client could write data the host's jj cannot read.
  packages = with pkgs; [
    nodejs_22
    git
    jq
    shellcheck
    shfmt
    graphviz
    tmux
    (import ./nix/hk.nix { inherit pkgs; })
  ];
}

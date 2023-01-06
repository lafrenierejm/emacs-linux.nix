{
  description = "Emacs with vterm";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    emacs-overlay = {
      url = github:nix-community/emacs-overlay;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, emacs-overlay, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ emacs-overlay.overlay self.overlay ];
      });
    in {

      packages = forAllSystems (system: {
        emacs = nixpkgsFor.${system}.emacs;
        emacs-i3-integration = nixpkgsFor.${system}.emacs-i3-integration;
        emacs-sway-integration = nixpkgsFor.${system}.emacs-sway-integration;
        emacs-xsway-integration = nixpkgsFor.${system}.emacs-xsway-integration;
      });

      overlay = final: prev: {

        emacs = ((prev.emacsPackagesFor (prev.emacsGit.overrideAttrs (
          old: rec {
            configureFlags = [
              "--disable-build-details"
              "--with-x-toolkit=lucid"
              "--with-native-compilation"
              "--with-xinput2"
            ];
            CFLAGS = "-O3 -pipe -march=native -fPIC -fomit-frame-pointer";
          }
        ))).emacsWithPackages (epkgs: with epkgs; [
          vterm
        ]));

        emacs-i3-integration = prev.writeShellScriptBin "emacs-i3-integration" ''
          if [[ $(${prev.xdotool}/bin/./xdotool getactivewindow getwindowclassname) == "Emacs" ]]; then
            command="(my/emacs-i3-integration \"$@\")"
            emacsclient -s x11 -e "$command"
          else
            i3-msg $@
          fi
        '';

        # TODO: test one of the two sway integrations. if one works, both should work

        # for non-pgtk emacs in sway with xwayland
        emacs-xsway-integration = prev.writeShellScriptBin "emacs-xsway-integration" ''
          if [[ $(swaymsg -t get_tree | ${prev.jq}/bin/./jq 'recurse(.nodes[]) | select(.focused) | .window_properties.class') == "Emacs" ]]; then
            command="(my/emacs-sway-integration \"$@\")"
            emacsclient -s wayland -e "$command"
          else
            swaymsg $@
          fi
        '';

        # for pgtk emacs in sway with pure wayland
        emacs-sway-integration = prev.writeShellScriptBin "emacs-sway-integration" ''
        if [[ $(swaymsg -t get_tree | ${prev.jq}/bin/./jq 'recurse(.nodes[]) | select(.focused) | .app_id') == "emacs" ]]; then
            command="(my/emacs-sway-integration \"$@\")"
            emacsclient -s wayland -e "$command"
          else
            swaymsg $@
          fi
        '';
      };
    };
}

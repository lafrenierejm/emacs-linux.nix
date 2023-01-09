{
  description = "Emacs with vterm";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    emacs-overlay = {
      url = github:nix-community/emacs-overlay;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-vterm-src = {
      url = github:akermu/emacs-libvterm;
      flake = false;
    };
    emacs-src = {
    #   url = git+https://git.savannah.gnu.org/git/emacs.git;
    #   rev = "cae528457cb862dc886a34240c9d4c73035b6659";
      url = github:emacs-mirror/emacs/cae528457cb862dc886a34240c9d4c73035b6659;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, emacs-overlay, emacs-vterm-src,
              emacs-src,
              ... }:
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
        emacs-vterm = nixpkgsFor.${system}.emacs-vterm;
        emacs-i3-integration = nixpkgsFor.${system}.emacs-i3-integration;
        emacs-sway-integration = nixpkgsFor.${system}.emacs-sway-integration;
        emacs-xsway-integration = nixpkgsFor.${system}.emacs-xsway-integration;
      });

      overlay = final: prev: {

        emacs-vterm = prev.stdenv.mkDerivation rec {
          pname = "emacs-vterm";
          version = "master";

          src = emacs-vterm-src;

          nativeBuildInputs = [
            prev.cmake
            prev.libtool
            prev.glib.dev
          ];

          buildInputs = [
            prev.glib.out
            prev.libvterm-neovim
            prev.ncurses
          ];

          cmakeFlags = [
            "-DUSE_SYSTEM_LIBVTERM=yes"
          ];

          preConfigure = ''
            echo "include_directories(\"${prev.glib.out}/lib/glib-2.0/include\")" >> CMakeLists.txt
            echo "include_directories(\"${prev.glib.dev}/include/glib-2.0\")" >> CMakeLists.txt
            echo "include_directories(\"${prev.ncurses.dev}/include\")" >> CMakeLists.txt
            echo "include_directories(\"${prev.libvterm-neovim}/include\")" >> CMakeLists.txt
          '';

          installPhase = ''
            mkdir -p $out
            cp ../vterm-module.so $out
            cp ../vterm.el $out
          '';
        };

        emacs = (prev.emacsGit.override {
          srcRepo = true;
          nativeComp = true;
          withSQLite3 = true;
          withGTK3 = true;
          withXinput2 = true;
          withWebP = true;
        }).overrideAttrs (
          old: rec {

            # # only needed if I decide to not start from the community overlay:
            # # note that not using the community overlay means losing builtin treesitter
            # version = "30.0.50";
            src = emacs-src;
            # patches = [ ];
            # postPatch = old.postPatch + ''
            #   substituteInPlace lisp/loadup.el \
            #   --replace '(emacs-repository-get-branch)' '"master"'
            # '';

            # # shouldn't need these, but it should also be equivalent:
            # configureFlags = [
            #   "--disable-build-details"
            #   "--with-x-toolkit=gtk3"
            #   "--with-native-compilation"
            #   "--with-xinput2"
            # ];

            CFLAGS = "-O3 -pipe -march=native -fPIC -fomit-frame-pointer";

            postInstall = old.postInstall + ''
              cp ${final.emacs-vterm}/vterm.el $out/share/emacs/site-lisp/vterm.el
              cp ${final.emacs-vterm}/vterm-module.so $out/share/emacs/site-lisp/vterm-module.so
            '';
          }
        );

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

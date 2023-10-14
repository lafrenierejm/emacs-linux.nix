{
  description = "Emacs with vterm";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    emacs-vterm-src = {
      url = github:akermu/emacs-libvterm;
      flake = false;
    };
    emacs29-src = {
      # url = git+https://git.savannah.gnu.org/git/emacs.git?ref=emacs-29;
      url = github:emacs-mirror/emacs/emacs-29;
      flake = false;
    };
    emacs30-src = {
      # url = git+https://git.savannah.gnu.org/git/emacs.git?ref=master;
      url = github:emacs-mirror/emacs/master;
      flake = false;
    };
  };

  outputs = { self,
              nixpkgs,
              emacs-vterm-src,
              emacs29-src,
              emacs30-src,
              ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });
    in {

      defaultPackage = forAllSystems (system: nixpkgsFor.${system}.emacs29);
      packages = forAllSystems (system: {
        emacs29 = nixpkgsFor.${system}.emacs29;
        emacs30 = nixpkgsFor.${system}.emacs30;
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

        emacs29 = (prev.emacs.override {
          srcRepo = true;
          withNativeCompilation = true;
          withSQLite3 = true;
          withGTK3 = true;
          withXinput2 = true;
          withWebP = true;
        }).overrideAttrs (
          old:

          let
            libName = drv: prev.lib.removeSuffix "-grammar" drv.pname;
            libSuffix = "so";
            lib = drv: ''lib${libName drv}.${libSuffix}'';
            linkCmd = drv: ''ln -s ${drv}/parser $out/lib/${lib drv}'';
            plugins = with final.pkgs.tree-sitter-grammars; [
              tree-sitter-bash
              tree-sitter-c
              tree-sitter-cmake
              tree-sitter-cpp
              tree-sitter-css
              tree-sitter-dockerfile
              tree-sitter-go
              tree-sitter-gomod
              tree-sitter-html
              tree-sitter-java
              tree-sitter-javascript
              tree-sitter-julia
              tree-sitter-json
              tree-sitter-python
              tree-sitter-ruby
              tree-sitter-rust
              tree-sitter-toml
              tree-sitter-tsx
              tree-sitter-typescript
              tree-sitter-yaml
            ];
            tree-sitter-grammars = prev.runCommandCC "tree-sitter-grammars" {}
              (prev.lib.concatStringsSep "\n" (["mkdir -p $out/lib"] ++ (map linkCmd plugins)));
          in rec {

            version = "29.0.60";
            src = emacs29-src;
            patches = [ ];
            postPatch = old.postPatch + ''
              substituteInPlace lisp/loadup.el \
              --replace '(emacs-repository-get-version)' '"${version}"' \
              --replace '(emacs-repository-get-branch)' '"emacs-29"'
            '' +
            (prev.lib.optionalString (old ? NATIVE_FULL_AOT)
              (let backendPath = (prev.lib.concatStringsSep " "
                (builtins.map (x: ''\"-B${x}\"'') [
                  # Paths necessary so the JIT compiler finds its libraries:
                  "${prev.lib.getLib final.libgccjit}/lib"
                  "${prev.lib.getLib final.libgccjit}/lib/gcc"
                  "${prev.lib.getLib final.stdenv.cc.libc}/lib"
                  
                  # Executable paths necessary for compilation (ld, as):
                  "${prev.lib.getBin final.stdenv.cc.cc}/bin"
                  "${prev.lib.getBin final.stdenv.cc.bintools}/bin"
                  "${prev.lib.getBin final.stdenv.cc.bintools.bintools}/bin"
                ]));
               in ''
                  substituteInPlace lisp/emacs-lisp/comp.el --replace \
                      "(defcustom comp-libgccjit-reproducer nil" \
                      "(setq native-comp-driver-options '(${backendPath}))
(defcustom comp-libgccjit-reproducer nil"
              ''));

            # this is necessary with GTK3 for treesitter to work
            nativeBuildInputs = (prev.lib.remove prev.wrapGAppsHook old.nativeBuildInputs);

            buildInputs = old.buildInputs ++ [ final.pkgs.tree-sitter tree-sitter-grammars ];
            TREE_SITTER_LIBS = "-ltree-sitter";
            postFixup = old.postFixup + ''
                ${final.pkgs.patchelf}/bin/patchelf --add-rpath ${prev.lib.makeLibraryPath [ tree-sitter-grammars ]} $out/bin/emacs
              '';

            # shouldn't need these, removing this should give the same build in theory
            configureFlags = [
              "--disable-build-details"
              "--with-x-toolkit=gtk3"
              "--with-native-compilation"
              "--with-xinput2"
            ];

            CFLAGS = "-O3 -pipe -march=native -fPIC -fomit-frame-pointer";

            # install vterm
            postInstall = old.postInstall + ''
              cp ${final.emacs-vterm}/vterm.el $out/share/emacs/site-lisp/vterm.el
              cp ${final.emacs-vterm}/vterm-module.so $out/share/emacs/site-lisp/vterm-module.so
            '';
          }
        );

        emacs30 = (prev.emacs.override {
          srcRepo = true;
          withNativeCompilation = true;
          withSQLite3 = true;
          withGTK3 = true;
          withXinput2 = true;
          withWebP = true;
        }).overrideAttrs (
          old:

          let
            libName = drv: prev.lib.removeSuffix "-grammar" drv.pname;
            libSuffix = "so";
            lib = drv: ''lib${libName drv}.${libSuffix}'';
            linkCmd = drv: ''ln -s ${drv}/parser $out/lib/${lib drv}'';
            plugins = with final.pkgs.tree-sitter-grammars; [
              tree-sitter-bash
              tree-sitter-c
              tree-sitter-cmake
              tree-sitter-cpp
              tree-sitter-css
              tree-sitter-dockerfile
              tree-sitter-go
              tree-sitter-gomod
              tree-sitter-html
              tree-sitter-java
              tree-sitter-javascript
              tree-sitter-julia
              tree-sitter-json
              tree-sitter-python
              tree-sitter-ruby
              tree-sitter-rust
              tree-sitter-toml
              tree-sitter-tsx
              tree-sitter-typescript
              tree-sitter-yaml
            ];
            tree-sitter-grammars = prev.runCommandCC "tree-sitter-grammars" {}
              (prev.lib.concatStringsSep "\n" (["mkdir -p $out/lib"] ++ (map linkCmd plugins)));
          in rec {

            version = "30.0.50";
            src = emacs30-src;
            patches = [ ];
            postPatch = old.postPatch + ''
              substituteInPlace lisp/loadup.el \
              --replace '(emacs-repository-get-version)' '"${version}"' \
              --replace '(emacs-repository-get-branch)' '"master"'
            '' +
            (prev.lib.optionalString (old ? NATIVE_FULL_AOT)
              (let backendPath = (prev.lib.concatStringsSep " "
                (builtins.map (x: ''\"-B${x}\"'') [
                  # Paths necessary so the JIT compiler finds its libraries:
                  "${prev.lib.getLib final.libgccjit}/lib"
                  "${prev.lib.getLib final.libgccjit}/lib/gcc"
                  "${prev.lib.getLib final.stdenv.cc.libc}/lib"
                  
                  # Executable paths necessary for compilation (ld, as):
                  "${prev.lib.getBin final.stdenv.cc.cc}/bin"
                  "${prev.lib.getBin final.stdenv.cc.bintools}/bin"
                  "${prev.lib.getBin final.stdenv.cc.bintools.bintools}/bin"
                ]));
               in ''
                  substituteInPlace lisp/emacs-lisp/comp.el --replace \
                      "(defcustom comp-libgccjit-reproducer nil" \
                      "(setq native-comp-driver-options '(${backendPath}))
(defcustom comp-libgccjit-reproducer nil"
              ''));

            # this is necessary with GTK3 for treesitter to work
            nativeBuildInputs = (prev.lib.remove prev.wrapGAppsHook old.nativeBuildInputs);

            buildInputs = old.buildInputs ++ [ final.pkgs.tree-sitter tree-sitter-grammars ];
            TREE_SITTER_LIBS = "-ltree-sitter";
            postFixup = old.postFixup + ''
                ${final.pkgs.patchelf}/bin/patchelf --add-rpath ${prev.lib.makeLibraryPath [ tree-sitter-grammars ]} $out/bin/emacs
              '';

            # shouldn't need these, removing this should give the same build in theory
            configureFlags = [
              "--disable-build-details"
              "--with-x-toolkit=gtk3"
              "--with-native-compilation"
              "--with-xinput2"
            ];

            CFLAGS = "-O3 -pipe -march=native -fPIC -fomit-frame-pointer";

            # install vterm
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





# {
#   inputs = {
#     nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
#     emacs-overlay.url = github:nix-community/emacs-overlay;
#     emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
#     emacs-vterm-src = {
#       url = github:akermu/emacs-libvterm;
#       flake = false;
#     };
#   };

#   outputs = { self, nixpkgs, emacs-overlay, emacs-vterm-src, ... }@inputs:

#     let
#       system = "x86_64-linux";
#       pkgs = import nixpkgs {
#         inherit system;
#         overlays = [
#           emacs-overlay.overlay
#         ];
#       };
#       # lib = nixpkgs.lib;
#       # final-pkgs = import nixpkgs {
#       #   inherit system;
#       #   overlays = [
#       #     emacs-overlay.overlay
#       #     self.overlay
#       #   ];
#       # };
#     in {

#       # defaultPackage.${system} = with final-pkgs; ((emacsPackagesFor myEmacs).emacsWithPackages
#       #   (epkgs: with epkgs; [
#       #     vterm
#       #   ]));

#       overlay = final: prev: {

#         emacs-vterm = prev.stdenv.mkDerivation rec {
#           pname = "emacs-vterm";
#           version = "master";

#           src = emacs-vterm-src;

#           nativeBuildInputs = [
#             prev.cmake
#             prev.libtool
#             prev.glib.dev
#           ];

#           buildInputs = [
#             prev.glib.out
#             prev.libvterm-neovim
#             prev.ncurses
#           ];

#           cmakeFlags = [
#             "-DUSE_SYSTEM_LIBVTERM=yes"
#           ];

#           preConfigure = ''
#             echo "include_directories(\"${prev.glib.out}/lib/glib-2.0/include\")" >> CMakeLists.txt
#             echo "include_directories(\"${prev.glib.dev}/include/glib-2.0\")" >> CMakeLists.txt
#             echo "include_directories(\"${prev.ncurses.dev}/include\")" >> CMakeLists.txt
#             echo "include_directories(\"${prev.libvterm-neovim}/include\")" >> CMakeLists.txt
#           '';

#           installPhase = ''
#             mkdir -p $out
#             cp ../vterm-module.so $out
#             cp ../vterm.el $out
#           '';
#         };

#         myEmacs = (prev.emacsGit.override {
#           srcRepo = true;
#           nativeComp = true;
#           withSQLite3 = true;
#           withGTK3 = true;
#           withXinput2 = true;
#           withWebP = true;
#           treeSitterPlugins = with prev.tree-sitter-grammars; [
#             tree-sitter-bash
#             tree-sitter-c
#             tree-sitter-cmake
#             tree-sitter-cpp
#             tree-sitter-css
#             tree-sitter-dockerfile
#             tree-sitter-go
#             tree-sitter-gomod
#             tree-sitter-html
#             tree-sitter-java
#             tree-sitter-javascript
#             tree-sitter-json
#             tree-sitter-julia
#             tree-sitter-python
#             tree-sitter-ruby
#             tree-sitter-rust
#             tree-sitter-toml
#             tree-sitter-tsx
#             tree-sitter-typescript
#             tree-sitter-yaml
#           ];
#         }).overrideAttrs (old:
#           rec {
#             CFLAGS = "-O3 -pipe -march=native -fPIC -fomit-frame-pointer";

#             # install vterm
#             postInstall = old.postInstall + ''
#               cp ${final.emacs-vterm}/vterm.el $out/share/emacs/site-lisp/vterm.el
#               cp ${final.emacs-vterm}/vterm-module.so $out/share/emacs/site-lisp/vterm-module.so
#             '';
#           });

#         emacs-i3-integration = prev.writeShellScriptBin "emacs-i3-integration" ''
#           if [[ $(${prev.xdotool}/bin/./xdotool getactivewindow getwindowclassname) == "Emacs" ]]; then
#             command="(my/emacs-i3-integration \"$@\")"
#             emacsclient -s x11 -e "$command"
#           else
#             i3-msg $@
#           fi
#         '';

#         # TODO: test one of the two sway integrations. if one works, both should work

#         # for non-pgtk emacs in sway with xwayland
#         emacs-xsway-integration = prev.writeShellScriptBin "emacs-xsway-integration" ''
#           if [[ $(swaymsg -t get_tree | ${prev.jq}/bin/./jq 'recurse(.nodes[]) | select(.focused) | .window_properties.class') == "Emacs" ]]; then
#             command="(my/emacs-sway-integration \"$@\")"
#             emacsclient -s wayland -e "$command"
#           else
#             swaymsg $@
#           fi
#         '';

#         # for pgtk emacs in sway with pure wayland
#         emacs-sway-integration = prev.writeShellScriptBin "emacs-sway-integration" ''
#         if [[ $(swaymsg -t get_tree | ${prev.jq}/bin/./jq 'recurse(.nodes[]) | select(.focused) | .app_id') == "emacs" ]]; then
#             command="(my/emacs-sway-integration \"$@\")"
#             emacsclient -s wayland -e "$command"
#           else
#             swaymsg $@
#           fi
#         '';

#       };
#     };
# }

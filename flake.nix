{
  description = "Emacs with vterm";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    emacs-vterm-src = {
      url = github:akermu/emacs-libvterm;
      flake = false;
    };
    emacs-src = {
      url = git+https://git.savannah.gnu.org/git/emacs.git;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, emacs-vterm-src, emacs-src, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });
    in {

      packages = forAllSystems (system: {
        emacs = nixpkgsFor.${system}.emacs;
        emacs-vterm = nixpkgsFor.${system}.emacs-vterm;
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

        emacs = (prev.emacs.override {
          srcRepo = true;
          nativeComp = true;
          withSQLite3 = true;
        }).overrideAttrs (
          old: rec {
            version = "30.0.50";
            src = emacs-src;
            patches = [ ];
            postPatch = old.postPatch + ''
              substituteInPlace lisp/loadup.el \
              --replace '(emacs-repository-get-branch)' '"master"'
            '';

            # Without nix, I usually configure like this:
            #   ./configure --with-native-compilation --with-pgtk \
            #               --prefix=$HOME/.local \
            #               CFLAGS='-O3 -pipe -march=native -fomit-frame-pointer -fPIC'

            # It seems like nix specifies a lot of things that are
            # actually default in emacs 29, and I have no idea if the
            # CFLAGS are actually getting through. The
            # --disable-build-details flag could be added to the
            # non-nix configure command to be more like nix. Of course
            # the prefix is different.

            # The parallel building works if the nix command is given
            # a --cores flag. It might work regardless, not sure.
            # Without nix, it's simply:
            #   make -jN where N is the number
            # of processes that are allowed to run in parallel.

            configureFlags = (prev.lib.remove "--with-xft" old.configureFlags)
                             ++ prev.lib.singleton "--with-pgtk";
            NIX_CFLAGS_COMPILE = [ (prev.NIX_CFLAGS_COMPILE or "") ]
                                 ++ [ "-O3" "-march=native" "-fPIC" "-fomit-frame-pointer" ];
            enableParallelBuilding = true;

            # I think with this, we do get vterm working correctly,
            # but it should probably be included in the emacs config
            # via:
            #   (use-package vterm :straight nil :ensure nil)
            postInstall = old.postInstall + ''
              cp ${final.emacs-vterm}/vterm.el $out/share/emacs/site-lisp/vterm.el
              cp ${final.emacs-vterm}/vterm-module.so $out/share/emacs/site-lisp/vterm-module.so
            '';
          }
        );
      };
    };
}

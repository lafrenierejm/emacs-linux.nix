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
            version = "29.0.50";
            src = emacs-src;
            patches = [ ];
            postPatch = old.postPatch + ''
              substituteInPlace lisp/loadup.el \
              --replace '(emacs-repository-get-branch)' '"master"'
            '';
            configureFlags = (prev.lib.remove "--with-xft" old.configureFlags)
                             ++ prev.lib.singleton "--with-pgtk";

            # TODO: site-lisp isn't in auto-loads, not sure what to do
            postInstall = old.postInstall + ''
              cp ${final.emacs-vterm}/vterm.el $out/share/emacs/site-lisp/vterm.el
              cp ${final.emacs-vterm}/vterm-module.so $out/share/emacs/site-lisp/vterm-module.so
            '';

            # Should this be CFLAGS? should I use configureFlagsArray?
            NIX_CFLAGS_COMPILE = [ "-O3" "-march=native" "-fomit-frame-pointer" ];

            enableParallelBuilding = true;
          }
        );
      };
    };
}

## Emacs with vterm on NixOS

This flake provides an overlay of emacs with vterm. It is used to be a modification of [this](https://github.com/cmacrae/emacs/blob/master/flake.nix), but that's now commented out and a much simpler version is left in its place. This is really just for personal use, but feel free to use anything you think would be useful.

## i3 and Sway integration

A few scripts are included as packages for integration with i3 and Sway as well. They require some emacs functions to be defined, some global i3/Sway keybindings, and the use of an emacs daemon.

- TODO: add the details for this

## Note to self

- I've explicitly overridden `configureFlags`. The `--disable-build-details` flag just makes the build slightly more reproducible.
- I'm not sure if I need so many CFLAGS... `CFLAGS='-O2 -march=native'` is probably fine.
- For loading vterm with `straight` and `straight-use-package`, I'm not sure if I should `(use-package vterm :straight nil :ensure nil)` or if `(use-package vterm)` is ok. Probably the latter is fine, but it does end up pulling some unnecessary stuff. Since the module is already available, it doesn't try to compile it again. The benefit is that the latter will still work on another system that doesn't include vterm.

Without nix, I usually configure like this for a wayland build:
```
./autogen.sh
./configure --with-native-compilation --with-pgtk \
            --prefix=$HOME/.local \
            CFLAGS='-O3 -pipe -march=native -fomit-frame-pointer -fPIC'
make -j$(nproc)
```

or like this for an X build (sometimes with the addition of `--with-x-toolkit=lucid`):
```
./autogen.sh
./configure --with-native-compilation --with-xinput2 \
            --prefix=$HOME/.local \
            CFLAGS='-O3 -pipe -march=native -fomit-frame-pointer -fPIC'
make -j$(nproc)
```

details about the CFLAGS can be found [here](https://wiki.gentoo.org/wiki/GCC_optimization#Optimizing).

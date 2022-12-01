## Emacs with vterm on NixOS

This flake provides an overlay of emacs to get vterm working. It is a modification of [this](https://github.com/cmacrae/emacs/blob/master/flake.nix). This is really just for personal use. I don't recommend basing your workflow on my repo.

## Note to self

- I've explicitly overridden `configureFlags`. The `--disable-build-details` flag just makes the build slightly more reproducible.
- I'm not sure if the CFLAGS are set up properly. Even if they are, `CFLAGS='-O2 -march=native'` is probably what I should be using.
- For loading vterm with `straight` and `straight-use-package`, I'm not sure if I need to do `(use-package vterm :straight nil :ensure nil)` or if `(use-package vterm)` is enough. Probably the latter is fine.
- It would be nice to get treesitter working like [here](https://github.com/nix-community/emacs-overlay/blob/6530a233351a806e88e83d10312d7dd9e8bc6cd3/overlays/emacs.nix#L72-L88).

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

This flake provides an overlay of emacs to get vterm working. It is a modifcation of [this](https://github.com/cmacrae/emacs/blob/master/flake.nix). This is really just for personal use. I don't recommend basing your workflow on my repo.

I've explicitly overridden `configureFlags`. The `--disable-build-details` flag just makes the build slightly more reproducible.

For loading vterm with straight, I'm not sure if I need to do `(use-package vterm :straight nil :ensure nil)` or if `(use-package vterm)` is enough.

Without nix, I usually configure like this for a wayland build:
```
./configure --with-native-compilation --with-pgtk \
            --prefix=$HOME/.local \
            CFLAGS='-O3 -pipe -march=native -fomit-frame-pointer -fPIC'
```

or like this for an X build (sometimes with the addition of `--with-x-toolkit=lucid`):
```
./configure --with-native-compilation --with-xinput2 \
            --prefix=$HOME/.local \
            CFLAGS='-O3 -pipe -march=native -fomit-frame-pointer -fPIC'
```

and then build with `make -j$(nproc)`.

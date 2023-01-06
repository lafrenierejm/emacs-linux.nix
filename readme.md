## Emacs with vterm on NixOS

This flake provides an overlay of emacs with vterm. Installing in emacs (rather than directly with nix as it's done here) doesn't work because the vterm module can't compile. This gives the overlay I like to use.

It is used to be a modification of [this](https://github.com/cmacrae/emacs/blob/master/flake.nix), but that's now removed and a much simpler version is left in its place. This is really just for personal use, but feel free to use anything you think would be useful.

## i3 and Sway integration

A few scripts are included for integration with i3 and Sway as well. They require some emacs functions to be defined, some global i3/Sway keybindings, and the use of an emacs daemon.

- TODO: add details

## Note to self

- I've explicitly overridden `configureFlags`. The `--disable-build-details` flag just makes the build slightly more reproducible. I could probably stick with defaults instead.
- I'm not sure if I need so many CFLAGS... `CFLAGS='-O2 -march=native'` is probably fine.
- Both of the above are to make it more like what I do without nix:

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

Details about the CFLAGS can be found [here](https://wiki.gentoo.org/wiki/GCC_optimization#Optimizing).

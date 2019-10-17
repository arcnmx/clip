# clip

Magical clipboard tool for copy and paste operations.

## Usage

```
$ clip -h
usage: clip [OPTIONS]
options:
-h: help
-i: copy to clipboard from stdin (default)
-z: clear the clipboard contents
-o: paste from clipboard to stdout

-p: use the primary selection (default)
-b: use the clipboard

-n: trim trailing newline when copying

-X: force X11 mode
-W: force Wayland mode
-O: force OSC52 mode
```

## Installation

### Nix

```shell
nix run -f https://github.com/arcnmx/clip/archive/master.tar.gz -c clip -h
```

### Other

```shell
install -m644 clip.sh /usr/local/bin/clip
```

## Dependencies

- bash
- coreutils
- xsel (optional)
- wl-clipboard (optional)

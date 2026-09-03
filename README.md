# figbar

A minimal, duo-tone status bar for Wayland compositors with native fractional scaling support. Forked from [ergo](https://github.com/pubfnmain/ergo).

## Dependencies

- wayland
- cairo
- pango
- wayland-protocols

## Usage

Use stdin to pass text for display.
Use `^` to highlight text (can be escaped with a backslash `\^`).

### Examples

```
while true; do echo $(date +%R); sleep 5; done | figbar -rN '3f3f3f'
```

```
echo " some ^ awesome ^ text " | figbar
```

![example](public/example0.png)
![example](public/example1.png)

## Thanks

- [ergo](https://github.com/pubfnmain/ergo) - original codebase
- [Wayland Book](https://wayland-book.com) - codebase reference
- [wmenu](https://sr.ht/~adnano/wmenu) - code examples (layer-shell, cairo, etc.)


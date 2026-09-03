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

```sh
while true; do echo $(date +%R); sleep 5; done | figbar -rN '3f3f3f'
```

```sh
echo " some ^ awesome ^ text " | figbar
```

### Sway Status Bar

![sway status](ex/sway_status.png)

A complete status generator for Sway is included in [`ex/sway_status.py`](ex/sway_status.py). It displays:
- Active and inactive Sway workspaces (highlighting the focused workspace with `^`)
- Audio volume & mute status (via `pamixer`)
- Battery level & charging indicator (`/sys/class/power_supply`)
- Screen brightness (via `brightnessctl`)
- Network SSID or Ethernet interface (`ip`, `iw`)
- Time and date

Run it with customized font and colors:

```sh
python3 ex/sway_status.py | figbar -b -r \
  -f "JetBrainsMono Nerd Font 10.5" \
  -N 272822 -n f8f8f2 \
  -S 66d9ef -s 272822
```

Flags used above:
- `-b`: Anchor bar to bottom (default: top)
- `-r`: Right-align status text (default: left)
- `-f`: Font family and size (Pango format)
- `-N` / `-n`: Normal background / foreground colors (hex)
- `-S` / `-s`: Selected (highlighted) background / foreground colors (hex)

## Thanks

- [ergo](https://github.com/pubfnmain/ergo) - original codebase
- [Wayland Book](https://wayland-book.com) - codebase reference
- [wmenu](https://sr.ht/~adnano/wmenu) - code examples (layer-shell, cairo, etc.)


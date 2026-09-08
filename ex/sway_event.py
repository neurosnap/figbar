#!/usr/bin/env python3
import json
import subprocess
import sys

def handle_click(event):
    key = event.get("key")
    btn = event.get("button", 1)
    if not key:
        return

    if key.startswith("ws_"):
        ws_name = key[3:]
        subprocess.run(["swaymsg", "workspace", ws_name], stderr=subprocess.DEVNULL)
    elif key == "vol":
        if btn == 1:
            # Left click: open volume control GUI
            subprocess.Popen(["pavucontrol"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        elif btn in (2, 3):
            # Middle/Right click: toggle mute
            subprocess.run(["pamixer", "-t"], stderr=subprocess.DEVNULL)
        elif btn == 4:
            # Scroll up: increase volume
            subprocess.run(["pamixer", "-i", "5"], stderr=subprocess.DEVNULL)
        elif btn == 5:
            # Scroll down: decrease volume
            subprocess.run(["pamixer", "-d", "5"], stderr=subprocess.DEVNULL)
    elif key == "brt":
        if btn == 4:
            subprocess.run(["brightnessctl", "set", "5%+"], stderr=subprocess.DEVNULL)
        elif btn == 5:
            subprocess.run(["brightnessctl", "set", "5%-"], stderr=subprocess.DEVNULL)

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
            if event.get("event") == "click":
                handle_click(event)
        except Exception:
            pass

if __name__ == "__main__":
    main()

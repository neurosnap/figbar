#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time

def get_sound():
    try:
        muted = subprocess.check_output(["pamixer", "--get-mute"], text=True, stderr=subprocess.DEVNULL).strip() == "true"
        vol = subprocess.check_output(["pamixer", "--get-volume"], text=True, stderr=subprocess.DEVNULL).strip()
        label = "MUTED" if muted else "VOL"
        return f"[[vol]]{label} {vol}%"
    except Exception:
        return "[[vol]]VOL ?"

def get_battery():
    if not os.path.exists("/sys/class/power_supply"):
        return None

    try:
        for bat in os.listdir("/sys/class/power_supply"):
            if not bat.startswith("BAT"):
                continue

            path = f"/sys/class/power_supply/{bat}"
            cap_file = f"{path}/capacity"
            if not os.path.exists(cap_file):
                continue

            with open(cap_file) as f:
                cap = f.read().strip()

            status = "BAT"
            stat_file = f"{path}/status"
            if os.path.exists(stat_file):
                with open(stat_file) as f:
                    if f.read().strip() == "Charging":
                        status = "CHR"

            return f"[[bat]]{status} {cap}%"
    except Exception:
        pass

    return None

def get_brightness():
    try:
        act = subprocess.check_output(["brightnessctl", "-c", "backlight", "get"], text=True, stderr=subprocess.DEVNULL).strip()
        max_b = subprocess.check_output(["brightnessctl", "-c", "backlight", "max"], text=True, stderr=subprocess.DEVNULL).strip()
        return f"[[brt]]BRT {int(int(act) * 100 / int(max_b))}%"
    except Exception:
        return None

def get_wifi_ssid(iface):
    try:
        out = subprocess.check_output(["iw", "dev", iface, "link"], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            if "SSID:" in line:
                return line.split("SSID:", 1)[1].strip()
    except Exception:
        pass
    return None

def get_net():
    try:
        route = subprocess.check_output(["ip", "route", "show", "default"], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return "[[net]]NET Disconnected"

    if "dev" not in route:
        return "[[net]]NET Disconnected"

    iface = route.split("dev")[1].split()[0]
    if not iface.startswith(("wl", "wlan")):
        return f"[[net]]ETH {iface}"

    ssid = get_wifi_ssid(iface)
    return f"[[net]]NET {ssid}" if ssid else f"[[net]]NET {iface}"

def get_time():
    return f"[[time]]{time.strftime('%I:%M %m/%d').lstrip('0')}"

def get_workspaces():
    try:
        out = subprocess.check_output(["swaymsg", "-t", "get_workspaces"], text=True, stderr=subprocess.DEVNULL)
        workspaces = json.loads(out)
    except Exception:
        return None

    if not workspaces:
        return None

    tags = [
        f"^[[ws_{w['name']}]] {w['name']} ^" if w.get("focused") else f"[[ws_{w['name']}]] {w['name']} "
        for w in sorted(workspaces, key=lambda x: x.get("num", 0))
    ]
    return "".join(tags)

def generate_line():
    status_parts = [p for p in [get_sound(), get_battery(), get_brightness(), get_net(), get_time()] if p]
    right_status = "  |  ".join(status_parts) + "  "

    ws = get_workspaces()
    if not ws:
        return right_status

    return f"{ws}    {right_status}"

def main():
    try:
        while True:
            print(generate_line(), flush=True)
            time.sleep(1)
    except (BrokenPipeError, KeyboardInterrupt):
        try:
            sys.stdout.close()
        except Exception:
            pass
        sys.exit(0)

if __name__ == "__main__":
    main()

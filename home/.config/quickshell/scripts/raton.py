#!/usr/bin/env python3
# Virtual mouse through uinput to test the shell (real clicks and drags; the user has
# permission on /dev/uinput). Hyprland's global coordinates (hyprctl cursorpos):
#   raton.py click x y
#   raton.py drag x1 y1 x2 y2 ["command in the middle of the drag, e.g. a grim screenshot"]
#   raton.py scroll x y n          (n > 0 down, n < 0 up; in wheel «clicks»)
import fcntl, os, struct, sys, time, subprocess
EV_SYN, EV_KEY, EV_REL = 0, 1, 2
BTN_LEFT, REL_X, REL_Y, REL_WHEEL = 0x110, 0, 1, 8
fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, 0x40045564, EV_KEY); fcntl.ioctl(fd, 0x40045564, EV_REL)
fcntl.ioctl(fd, 0x40045565, BTN_LEFT)
fcntl.ioctl(fd, 0x40045566, REL_X); fcntl.ioctl(fd, 0x40045566, REL_Y); fcntl.ioctl(fd, 0x40045566, REL_WHEEL)
os.write(fd, struct.pack("80s4HI", b"raton-prueba", 3, 1, 1, 1, 0) + b"\0" * (256 * 4))
fcntl.ioctl(fd, 0x5501)
time.sleep(1)
def ev(t, c, v): os.write(fd, struct.pack("llHHi", 0, 0, t, c, v))
def syn(): ev(EV_SYN, 0, 0)
def pos():
    x, y = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True).stdout.split(",")
    return float(x), float(y)
def warp(x, y): subprocess.run(["hyprctl", "dispatch", f"hl.dsp.cursor.move({{ x = {x}, y = {y} }})"], capture_output=True)
def btn(v): ev(EV_KEY, BTN_LEFT, v); syn()
def moveto(x, y, step=6):
    for _ in range(400):
        cx, cy = pos()
        dx, dy = x - cx, y - cy
        if abs(dx) < 3 and abs(dy) < 3: return
        ev(EV_REL, REL_X, int(max(-step, min(step, dx)))); ev(EV_REL, REL_Y, int(max(-step, min(step, dy)))); syn()
        time.sleep(0.012)
a = sys.argv[1:]
if a[0] == "drag":
    x1, y1, x2, y2 = map(float, a[1:5])
    warp(x1 - 20, y1); time.sleep(0.2); moveto(x1, y1); time.sleep(0.4)
    btn(1); time.sleep(0.15)
    moveto(x2, y2)
    if len(a) > 5: subprocess.run(["sh", "-c", a[5]]); time.sleep(0.1)
    time.sleep(0.3); btn(0)
elif a[0] == "click":
    x, y = map(float, a[1:3])
    warp(x - 20, y); time.sleep(0.2); moveto(x, y); time.sleep(0.3)
    btn(1); time.sleep(0.08); btn(0)
elif a[0] == "scroll":
    x, y, n = float(a[1]), float(a[2]), int(a[3])
    warp(x - 20, y); time.sleep(0.2); moveto(x, y); time.sleep(0.3)
    for _ in range(abs(n)):
        ev(EV_REL, REL_WHEEL, -1 if n > 0 else 1); syn(); time.sleep(0.05)
time.sleep(0.3)
fcntl.ioctl(fd, 0x5502); os.close(fd)

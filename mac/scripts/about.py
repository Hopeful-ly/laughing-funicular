#!/usr/bin/env python3
"""About This Computer: the classic spinning ASCII donut (a Python/numpy port
of Andy Sloane's donut.c) next to fastfetch's system info.

Keys: q / Esc / Enter quit · space pause · c toggle colour · + / - speed
"""
import math, os, re, select, shutil, signal, subprocess, sys, termios, time, tty
import numpy as np

COLS, ROWS = 44, 22            # donut canvas in terminal cells
FPS = 30
RAMP = np.array(list(".,-~:;=!*#$@"))
R1, R2, K2 = 1.0, 2.0, 5.0     # tube radius, ring radius, viewer distance
K1 = COLS * K2 * 3 / (8 * (R1 + R2))

# Sample the torus surface once; rotate per frame.
theta = np.arange(0, 2 * math.pi, 0.07)
phi = np.arange(0, 2 * math.pi, 0.02)
TH, PH = np.meshgrid(theta, phi, indexing="ij")
ct, st, cp, sp = np.cos(TH), np.sin(TH), np.cos(PH), np.sin(PH)
circx, circy = R2 + R1 * ct, R1 * st

def frame(A, B):
    cA, sA, cB, sB = math.cos(A), math.sin(A), math.cos(B), math.sin(B)
    x = circx * (cB * cp + sA * sB * sp) - circy * cA * sB
    y = circx * (sB * cp - sA * cB * sp) + circy * cA * cB
    z = K2 + cA * circx * sp + circy * sA
    ooz = 1 / z
    xp = (COLS / 2 + K1 * ooz * x).astype(int)
    yp = (ROWS / 2 - K1 * ooz * y / 2).astype(int)        # /2: cells are twice as tall
    L = cp * ct * sB - cA * ct * sp - sA * st + cB * (cA * st - ct * sA * sp)
    ok = (L > 0) & (xp >= 0) & (xp < COLS) & (yp >= 0) & (yp < ROWS)
    xp, yp, ooz, L = xp[ok], yp[ok], ooz[ok], L[ok]
    # z-buffer: keep the nearest point per cell (sort far->near, last write wins)
    order = np.argsort(ooz)
    idx = yp[order] * COLS + xp[order]
    lum = np.zeros(ROWS * COLS)
    hit = np.zeros(ROWS * COLS, bool)
    lum[idx] = L[order]
    hit[idx] = True
    return lum.reshape(ROWS, COLS), hit.reshape(ROWS, COLS)

def gradient(t):
    """Luminance 0..1 -> colour (deep blue -> cyan -> near white)."""
    stops = [(0.0, (40, 60, 160)), (0.45, (60, 140, 255)), (0.75, (90, 220, 255)), (1.0, (235, 250, 255))]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
    return stops[-1][1]
PALETTE = [gradient(i / 11) for i in range(12)]

def to_lines(lum, hit, colour):
    li = np.clip((lum * 8).astype(int), 0, 11)
    lines = []
    for r in range(ROWS):
        out, last = [], -1
        for c in range(COLS):
            if not hit[r, c]:
                out.append(" "); continue
            k = li[r, c]
            if colour and k != last:
                p = PALETTE[k]; out.append(f"\x1b[38;2;{p[0]};{p[1]};{p[2]}m"); last = k
            out.append(RAMP[k])
        lines.append("".join(out) + "\x1b[0m")
    return lines

ANSI = re.compile(r"\x1b\[[0-9;]*m")
def vis_len(s): return len(ANSI.sub("", s))
def clip(s, n):
    """Truncate to n visible characters, keeping colour codes intact."""
    out, seen, i = [], 0, 0
    while i < len(s) and seen < n:
        m = ANSI.match(s, i)
        if m: out.append(m.group()); i = m.end(); continue
        out.append(s[i]); seen += 1; i += 1
    if seen >= n and i < len(s): out[-1] = "…"
    return "".join(out) + "\x1b[0m"

def main():
    # Launched through the login shell so fastfetch reports it (not "about.py").
    shell = os.environ.get("SHELL", "bash")
    info = subprocess.run([shell, "-c", "fastfetch --logo none --pipe false"],
                          capture_output=True, text=True).stdout.rstrip("\n").split("\n")
    cols, _ = shutil.get_terminal_size()
    side = cols >= COLS + 30          # beside the donut unless really narrow
    info_x = COLS + 5 if side else 2
    art_y = 2 + (max(0, (len(info) - ROWS) // 2) if side else 0)
    info_y = 2 if side else art_y + ROWS + 1

    out = sys.stdout
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    tty.setcbreak(fd)
    out.write("\x1b[?1049h\x1b[?25l\x1b[2J")          # alternate screen, hide cursor
    def cleanup(*_):
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        out.write("\x1b[0m\x1b[?25h\x1b[?1049l"); out.flush()
        sys.exit(0)
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGHUP, cleanup)

    room = max(10, cols - info_x - 1)
    for i, line in enumerate(info):
        out.write(f"\x1b[{info_y + i};{info_x}H{clip(line, room)}")
    hint = "\x1b[2mq quit · space pause · c colour · +/- speed\x1b[0m"
    out.write(f"\x1b[{max(info_y + len(info), art_y + ROWS) + 1};2H{hint}")

    A = B = 0.0
    speed, paused, colour = 1.0, False, True
    last = time.time()
    try:
        while True:
            now = time.time(); dt = now - last; last = now
            if not paused:
                A += 1.2 * dt * speed          # same ratio as donut.c (0.04 : 0.02)
                B += 0.6 * dt * speed
            lum, hit = frame(A, B)
            for i, l in enumerate(to_lines(lum, hit, colour)):
                out.write(f"\x1b[{art_y + i};2H{l}")
            out.flush()
            if select.select([sys.stdin], [], [], 1 / FPS)[0]:
                ch = os.read(fd, 8)
                if ch in (b"q", b"Q", b"\x1b", b"\n", b"\r"): break
                elif ch == b" ": paused = not paused
                elif ch in (b"c", b"C"): colour = not colour
                elif ch in (b"+", b"="): speed = min(4.0, speed * 1.25)
                elif ch in (b"-", b"_"): speed = max(0.25, speed / 1.25)
    except KeyboardInterrupt:
        pass
    cleanup()

if __name__ == "__main__":
    main()

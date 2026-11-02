#!/usr/bin/env python3
"""Drive the Windows VM through QEMU's QMP socket.

  vmctl.py shot out.png        screenshot of the VM display
  vmctl.py key ret             press a key or combo (e.g. shift-f10, meta_l-r)
  vmctl.py type 'text'         type literal text
  vmctl.py status              VM run state
"""
import json, os, socket, subprocess, sys, time

SOCK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qmp.sock")

def connect():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    f = s.makefile("rw")
    f.readline()  # greeting
    cmd(f, "qmp_capabilities")
    return s, f

def cmd(f, name, **args):
    f.write(json.dumps({"execute": name, "arguments": args} if args else {"execute": name}) + "\n")
    f.flush()
    while True:
        r = json.loads(f.readline())
        if "event" in r:
            continue
        if "error" in r:
            raise SystemExit(f"QMP error: {r['error']}")
        return r.get("return")

SHIFTED = {'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8',
           '(': '9', ')': '0', '_': 'minus', '+': 'equal', '{': 'bracket_left',
           '}': 'bracket_right', '|': 'backslash', ':': 'semicolon', '"': 'apostrophe',
           '<': 'comma', '>': 'dot', '?': 'slash', '~': 'grave_accent'}
PLAIN = {' ': 'spc', '-': 'minus', '=': 'equal', '[': 'bracket_left', ']': 'bracket_right',
         '\\': 'backslash', ';': 'semicolon', "'": 'apostrophe', ',': 'comma', '.': 'dot',
         '/': 'slash', '`': 'grave_accent', '\n': 'ret', '\t': 'tab'}

def keys_for_char(c):
    if c.isalpha():
        return (["shift", c.lower()] if c.isupper() else [c])
    if c.isdigit():
        return [c]
    if c in PLAIN:
        return [PLAIN[c]]
    if c in SHIFTED:
        return ["shift", SHIFTED[c]]
    raise SystemExit(f"cannot type {c!r}")

def send(f, combo, hold=80):
    keys = [{"type": "qcode", "data": k} for k in combo]
    cmd(f, "send-key", keys=keys, **{"hold-time": hold})

def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    op = sys.argv[1]
    s, f = connect()
    try:
        if op == "shot":
            out = os.path.abspath(sys.argv[2])
            ppm = out + ".ppm"
            cmd(f, "screendump", filename=ppm)
            subprocess.run(["sips", "-s", "format", "png", ppm, "--out", out],
                           check=True, capture_output=True)
            os.remove(ppm)
            print(out)
        elif op == "key":
            for combo in sys.argv[2:]:
                send(f, combo.split("-"))
                time.sleep(0.15)
        elif op == "type":
            for c in " ".join(sys.argv[2:]):
                send(f, keys_for_char(c), hold=40)
                time.sleep(0.03)
        elif op == "status":
            print(cmd(f, "query-status"))
        else:
            raise SystemExit(__doc__)
    finally:
        s.close()

if __name__ == "__main__":
    main()

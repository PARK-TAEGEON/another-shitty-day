#!/usr/bin/env python3
"""Run a Godot capture or other GUI command in an authenticated Linux Xvfb.

The display server and child command share one process environment. This is
useful in CI where the default Unix display socket is unavailable. No network
policy or proxy settings are changed. Xvfb, xauth, and xkbcomp must be installed.

Example:
    python tools/with_display.py -- godot --path game --audio-driver Dummy

For unpacked dependencies, pass --xvfb and --xauth paths and --library-dir.
The child can save screenshots itself, or use Godot's --write-movie option.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time


def find_executable(value: str | None, fallback: str) -> str:
    result = value or shutil.which(fallback)
    if not result or not Path(result).is_file():
        raise RuntimeError(f"Missing {fallback}; install it or pass --{fallback.lower()}.")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xvfb", help="Path to the Xvfb executable")
    parser.add_argument("--xauth", help="Path to the xauth executable")
    parser.add_argument("--library-dir", help="Directory of unpacked X11 shared libraries")
    parser.add_argument("--display", type=int, default=97, help="Local X display number")
    parser.add_argument("--size", default="1280x720x24", help="Xvfb WIDTHxHEIGHTxDEPTH")
    parser.add_argument("--timeout", type=float, default=120, help="Child timeout in seconds")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("Pass a command after --.")
    if not 0 <= args.display <= 59535:
        parser.error("Display must be between 0 and 59535.")

    xvfb = find_executable(args.xvfb, "Xvfb")
    xauth = find_executable(args.xauth, "xauth")
    env = os.environ.copy()
    env["DISPLAY"] = f"127.0.0.1:{args.display}"
    env.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
    if args.library_dir:
        existing = env.get("LD_LIBRARY_PATH", "")
        env["LD_LIBRARY_PATH"] = args.library_dir + (":" + existing if existing else "")

    with tempfile.TemporaryDirectory(prefix="desk-breaker-display-") as temporary:
        temp_path = Path(temporary)
        auth_path = temp_path / "authority"
        auth_path.touch(mode=0o600)
        env["XAUTHORITY"] = str(auth_path)
        cookie = secrets.token_hex(16)
        auth = subprocess.run(
            [xauth, "-f", str(auth_path), "source", "-"],
            input=f"add {env['DISPLAY']} MIT-MAGIC-COOKIE-1 {cookie}\n",
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            timeout=5,
        )
        if auth.returncode:
            raise RuntimeError("Could not create Xvfb authentication: " + auth.stderr.strip())

        with (temp_path / "xvfb.log").open("w+") as server_log:
            server = subprocess.Popen(
                [xvfb, f":{args.display}", "-screen", "0", args.size,
                 "-nolisten", "unix", "-nolisten", "local", "-listen", "tcp",
                 "-noreset", "-auth", str(auth_path)],
                env=env,
                stdout=server_log,
                stderr=subprocess.STDOUT,
            )
            try:
                ready = False
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if server.poll() is not None:
                        break
                    try:
                        with socket.create_connection(("127.0.0.1", 6000 + args.display), timeout=0.1):
                            ready = True
                            break
                    except OSError:
                        time.sleep(0.1)
                if not ready:
                    server_log.seek(0)
                    raise RuntimeError("Xvfb did not start:\n" + server_log.read())
                return subprocess.run(command, env=env, timeout=args.timeout).returncode
            finally:
                server.terminate()
                try:
                    server.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Display runner failed: {error}", file=sys.stderr)
        raise SystemExit(1)

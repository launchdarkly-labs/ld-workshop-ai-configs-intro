#!/usr/bin/env python3
"""Install Coordinate ch07's Concierge dispatch into app/server.py.

Replaces the single-Otto request path — everything from the
`# ─── Challenge 01: wire Otto to /chat` comment up to (not including) the
`# ─── Challenge 07 judge injects below this marker` comment — with the
graph-driven dispatch in concierge-server-paste.py. The Evaluate-era judge
blocks below the marker are untouched; they now grade the rewriter's output.

Idempotent: if the paste's header comment is already present, no-op.
"""
from __future__ import annotations

import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "coordinate-07" / "concierge-server-paste.py"
START = "    # ─── Challenge 01: wire Otto to /chat"
END = "    # ─── Challenge 07 judge injects below this marker"
SIGNATURE = "# ─── Coordinate 07: Concierge dispatch"


def main() -> int:
    text = SERVER_PY.read_text()
    if SIGNATURE in text:
        print("server.py already has the Concierge dispatch — patch is a no-op.")
        return 0
    start = text.find(START)
    end = text.find(END)
    if start < 0 or end < 0 or end < start:
        print(
            "ERROR: could not find the Challenge 01 block and the Challenge 07 marker in server.py. "
            "Has the Build ch01 patch been applied?",
            file=sys.stderr,
        )
        return 1
    paste = PASTE_FILE.read_text()
    SERVER_PY.write_text(text[:start] + paste + text[end:])
    print(f"Patched {SERVER_PY} with the Concierge dispatch (replaced the single-Otto block)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

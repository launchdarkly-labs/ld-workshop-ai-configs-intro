#!/usr/bin/env python3
"""Install Coordinate ch10's self-healing block into app/server.py.

Inserts selfheal-server-paste.py immediately below the
`# ─── Coordinate 10: self-healing hook` comment that ch07's Concierge
dispatch left for it. Idempotent: no-op if SELF_HEAL_THRESHOLD is present.
"""
from __future__ import annotations

import pathlib
import sys

REPO_ROOT = pathlib.Path("/opt/ld/ai-configs-intro")
SERVER_PY = REPO_ROOT / "app" / "server.py"
PASTE_FILE = REPO_ROOT / "terraform" / "coordinate-10" / "selfheal-server-paste.py"
HOOK = "    # ─── Coordinate 10: self-healing hook ───────────────────────────────────\n"
HOOK_TAIL = "    #  this comment. It may replace `assistant_text` and `model_id`.)\n"
SIGNATURE = "SELF_HEAL_THRESHOLD"


def main() -> int:
    text = SERVER_PY.read_text()
    if SIGNATURE in text:
        print("server.py already has the self-healing block — patch is a no-op.")
        return 0
    if HOOK not in text or HOOK_TAIL not in text:
        print(
            "ERROR: could not find the Coordinate 10 hook in server.py. "
            "Has Challenge 07's Concierge dispatch been applied?",
            file=sys.stderr,
        )
        return 1
    idx = text.index(HOOK_TAIL) + len(HOOK_TAIL)
    paste = PASTE_FILE.read_text()
    SERVER_PY.write_text(text[:idx] + "\n" + paste + text[idx:])
    print(f"Patched {SERVER_PY} with the self-healing block")
    return 0


if __name__ == "__main__":
    sys.exit(main())

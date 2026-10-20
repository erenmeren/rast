#!/usr/bin/env python3
"""Verify all payload files against the SHA256SUMS.txt exported with this package."""
import hashlib
from pathlib import Path
import sys

def main():
    root = Path(__file__).resolve().parents[1]
    index = root / "SHA256SUMS.txt"
    if not index.is_file():
        sys.exit("SHA256SUMS.txt is missing; extract the complete archive.")
    checked = 0
    failures = []
    for line in index.read_text(encoding="utf-8").splitlines():
        expected, relative = line.split("  ", 1)
        target = (root / relative).resolve()
        if root != target and root not in target.parents:
            failures.append(f"Unsafe path: {relative}")
            continue
        if not target.is_file():
            failures.append(f"Missing: {relative}")
            continue
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        if actual != expected:
            failures.append(f"Changed: {relative}")
        checked += 1
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print(f"Verified {checked} payload files. SHA256SUMS.txt does not hash itself.")

if __name__ == "__main__":
    main()


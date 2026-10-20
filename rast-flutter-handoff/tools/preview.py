#!/usr/bin/env python3
"""Serve the bundled web reference locally using Python's standard library."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import webbrowser

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8020)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Choose a port between 1024 and 65535.")
    root = Path(__file__).resolve().parents[1] / "prototype" / "dist"
    if not (root / "index.html").is_file():
        parser.error("Extract the complete ZIP first; prototype/dist/index.html is missing.")
    handler = partial(SimpleHTTPRequestHandler, directory=str(root))
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    except OSError as exc:
        parser.exit(1, f"Cannot open the local preview: {exc}. Try --port 8021.\n")
    url = f"http://127.0.0.1:{args.port}/"
    print(f"rast design preview: {url}\nPress Ctrl+C to stop.", flush=True)
    if not args.no_browser:
        try:
            webbrowser.open(url)
        except Exception:
            print("Open the address above in your browser.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nPreview stopped.")
    finally:
        server.server_close()

if __name__ == "__main__":
    main()


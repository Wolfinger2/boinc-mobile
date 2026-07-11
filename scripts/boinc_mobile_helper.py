#!/usr/bin/env python3
import argparse
import json
import socket
import time


def detect_address() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "0.0.0.0"
    finally:
        sock.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", default=socket.gethostname())
    parser.add_argument("--boinc-port", type=int, default=31416)
    parser.add_argument("--discovery-port", type=int, default=31417)
    parser.add_argument("--interval", type=float, default=3.0)
    args = parser.parse_args()

    address = detect_address()
    payload = json.dumps({
        "service": "boinc-mobile-helper",
        "version": 1,
        "name": args.name,
        "address": address,
        "port": args.boinc_port,
    }).encode("utf-8")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    print(f"BOINC Mobile Helper: {args.name} ({address}:{args.boinc_port})")
    print("Beenden mit Strg+C.")
    try:
        while True:
            sock.sendto(payload, ("255.255.255.255", args.discovery_port))
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("
Helper beendet.")
    finally:
        sock.close()


if __name__ == "__main__":
    main()

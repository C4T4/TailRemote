#!/usr/bin/env python3
"""Export connection names, never credentials, from the Mac's Tailscale list."""
import argparse
import getpass
import json
import os
import re
from pathlib import Path
import shutil
import subprocess


def export_macs(status, local_username):
    devices = [status.get("Self", {})] + list((status.get("Peer") or {}).values())
    macs = []
    for index, device in enumerate(devices):
        if device.get("OS") != "macOS":
            continue
        dns = (device.get("DNSName") or "").rstrip(".")
        addresses = device.get("TailscaleIPs") or []
        hostname = dns or next((ip for ip in addresses if ":" not in ip), "")
        if not hostname:
            continue
        name = device.get("HostName") or dns.split(".")[0] or hostname
        aliases = sorted({address for address in [name, *addresses, *([dns.split(".")[0]] if dns else [])]
                          if re.fullmatch(r"[A-Za-z0-9.:-]+", address)})
        macs.append({"hostname": hostname, "name": name,
                     "username": local_username if index == 0 else "", "aliases": aliases})
    return {"version": 1, "macs": macs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Private output JSON file, outside the repository")
    args = parser.parse_args()
    cli = shutil.which("tailscale")
    if not cli:
        parser.error("Tailscale CLI is not installed or not on PATH")
    result = subprocess.run([cli, "status", "--json"], capture_output=True, text=True, timeout=15)
    if result.returncode:
        parser.error("Could not read Tailscale. Open Tailscale and connect first.")
    status = json.loads(result.stdout)
    if status.get("BackendState") != "Running":
        parser.error("Connect Tailscale before exporting Macs.")
    exported = export_macs(status, getpass.getuser())
    if not exported["macs"]:
        parser.error("No Macs were found in this Tailscale device list.")
    # Exclusive creation avoids overwriting another file or following a symlink.
    with os.fdopen(os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as out:
        json.dump(exported, out, indent=2)
    print(f"Exported {len(exported['macs'])} Mac(s). No passwords or tokens included.")


if __name__ == "__main__":
    main()

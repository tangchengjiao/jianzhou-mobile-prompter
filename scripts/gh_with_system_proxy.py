"""Run gh using the existing Windows proxy, without changing system settings."""
import os
import subprocess
import shutil
import sys
import urllib.request

environment = os.environ.copy()
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
for protocol, proxy in urllib.request.getproxies().items():
    if protocol in {"http", "https"}:
        environment[protocol.upper() + "_PROXY"] = proxy
executable = shutil.which("gh")
if executable is None:
    raise SystemExit("GitHub CLI is not on PATH.")
raise SystemExit(subprocess.run([executable, *sys.argv[1:]], env=environment).returncode)

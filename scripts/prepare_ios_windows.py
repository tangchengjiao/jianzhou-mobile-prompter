"""Download the Windows prerequisites linked by AltStore's official installation guide.

Only prepares files; installation, device trust and Apple ID sign-in remain local actions.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
import urllib.request
import zipfile

DOWNLOADS = {
    "AltInstaller.zip": "https://cdn.altstore.io/file/altstore/altinstaller.zip",
    "iTunes64Setup.exe": "https://www.apple.com/itunes/download/win64",
    "iCloudSetup.exe": "https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe",
}


def download(directory: Path, item: tuple[str, str]) -> Path:
    name, url = item
    destination = directory / name
    if destination.exists():
        print(f"Ready: {name} ({destination.stat().st_size:,} bytes)", flush=True)
        return destination
    request = urllib.request.Request(url, headers={"User-Agent": "Jianzhou-iOS-Setup/1.0"})
    temporary = destination.with_suffix(destination.suffix + ".part")
    with urllib.request.urlopen(request, timeout=45) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    signature = temporary.open("rb").read(2)
    if signature != (b"PK" if name.endswith(".zip") else b"MZ"):
        raise RuntimeError(f"{name}: the server did not return the expected installer")
    temporary.replace(destination)
    print(f"Downloaded: {name} ({destination.stat().st_size:,} bytes)", flush=True)
    return destination


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("D:/DevCaches/jianzhou-mobile/ios-installers"))
    directory = parser.parse_args().directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        for _ in pool.map(lambda item: download(directory, item), DOWNLOADS.items()):
            pass
    with zipfile.ZipFile(directory / "AltInstaller.zip") as archive:
        archive.extractall(directory / "AltInstaller")
        print("AltServer installer files: " + ", ".join(archive.namelist()))
    print(f"Prepared in: {directory}")


if __name__ == "__main__":
    main()

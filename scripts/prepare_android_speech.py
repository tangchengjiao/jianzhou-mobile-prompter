"""Download the Android experiment's official speech resources into local assets."""
import argparse
from pathlib import Path
import shutil
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MODEL_URL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16.tar.bz2"
AAR_URL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-1.13.8.aar"
FILES = {
    "encoder-epoch-99-avg-1.int8.onnx": "encoder.int8.onnx",
    "decoder-epoch-99-avg-1.onnx": "decoder.onnx",
    "joiner-epoch-99-avg-1.int8.onnx": "joiner.int8.onnx",
    "tokens.txt": "tokens.txt",
}


def download(url, target):
    if target.is_file() and target.stat().st_size:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_suffix(target.suffix + ".part")
    print("Downloading", target.name, flush=True)
    with urllib.request.urlopen(url, timeout=120) as source, part.open("wb") as output:
        shutil.copyfileobj(source, output)
    part.replace(target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, required=True)
    options = parser.parse_args()
    archive = options.cache / "chinese-bilingual-model.tar.bz2"
    assets = ROOT / "android/app/src/main/assets/asr-zh"
    assets.mkdir(parents=True, exist_ok=True)
    download(AAR_URL, ROOT / "android/app/libs/sherpa-onnx-1.13.8.aar")
    if not all((assets / name).is_file() for name in FILES.values()):
        download(MODEL_URL, archive)
        with tarfile.open(archive) as package:
            for member in package:
                parts = Path(member.name).parts
                if member.isfile() and len(parts) == 2 and parts[-1] in FILES:
                    with package.extractfile(member) as source, (assets / FILES[parts[-1]]).open("wb") as output:
                        shutil.copyfileobj(source, output)
        if not all((assets / name).is_file() for name in FILES.values()):
            raise RuntimeError("The official model archive is missing expected files.")
    print("Android speech resources ready.")


if __name__ == "__main__":
    main()

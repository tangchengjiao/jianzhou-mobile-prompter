"""Exercise actual packaged speech models on official sample audio (desktop only)."""
import argparse
import json
from pathlib import Path
import sys
import time
import wave


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--deps", required=True)
    args.add_argument("--model", required=True)
    args.add_argument("--samples", required=True)
    args.add_argument("--output", required=True)
    options = args.parse_args()
    sys.path.insert(0, options.deps)
    sys.stdout.reconfigure(encoding="utf-8")
    import numpy as np
    import sherpa_onnx

    folder = Path(options.model)
    recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
        tokens=str(folder / "tokens.txt"),
        encoder=str(folder / "encoder.int8.onnx"),
        decoder=str(folder / "decoder.onnx"),
        joiner=str(folder / "joiner.int8.onnx"),
        num_threads=2,
        sample_rate=16000,
        decoding_method="greedy_search",
        model_type="",
        provider="cpu",
    )
    rows = []
    for path in sorted(Path(options.samples).glob("*.wav")):
        with wave.open(str(path), "rb") as audio:
            assert audio.getnchannels() == 1 and audio.getsampwidth() == 2
            rate = audio.getframerate()
            samples = np.frombuffer(audio.readframes(audio.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        stream = recognizer.create_stream()
        updates = []
        last = ""
        started = time.perf_counter()
        chunk = int(rate * 0.1)
        for begin in range(0, len(samples), chunk):
            stream.accept_waveform(rate, samples[begin:begin + chunk])
            while recognizer.is_ready(stream):
                recognizer.decode_stream(stream)
            text = recognizer.get_result(stream)
            if text != last:
                updates.append({"audioSecondsFed": round(min(len(samples), begin + chunk) / rate, 2), "text": text})
                last = text
        stream.accept_waveform(rate, np.zeros(int(rate * 0.5), dtype=np.float32))
        stream.input_finished()
        while recognizer.is_ready(stream):
            recognizer.decode_stream(stream)
        elapsed = time.perf_counter() - started
        text = recognizer.get_result(stream)
        assert text.strip(), f"No transcript for {path.name}"
        row = {"sample": path.name, "audioSeconds": round(len(samples) / rate, 3), "desktopComputeSeconds": round(elapsed, 3), "transcript": text, "partialUpdates": updates}
        rows.append(row)
        print(json.dumps({k: v for k, v in row.items() if k != "partialUpdates"}, ensure_ascii=False))
    report = {"scope": "Windows desktop CPU probe using official sample audio. Does not verify Android JNI, phone speed, microphone sharing or user accuracy.", "sherpaVersion": sherpa_onnx.__version__, "results": rows}
    target = Path(options.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()

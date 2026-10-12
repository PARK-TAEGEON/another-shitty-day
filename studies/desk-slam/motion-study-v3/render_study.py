#!/usr/bin/env python3
"""Render the intro B / repeat A sequence, using the original identical impact sound.

Use an available display or pass --display-runner with the supplied project's
Xvfb helper and dependency paths. No network services are called.
"""
from __future__ import annotations

import argparse
import array
import json
import math
from pathlib import Path
import random
import shutil
import subprocess
import wave

ROOT = Path(__file__).resolve().parent
FPS = 30
NFRAMES = 240
RATE = 48000


def run(command: list[str]) -> None:
    print("Running:", command[0], " ".join(command[1:5]), flush=True)
    subprocess.run(command, check=True)


def impact() -> list[float]:
    rng = random.Random(48628)
    output = []
    previous = 0.0
    for n in range(int(RATE * 0.54)):
        t = n / RATE
        attack = min(1.0, t / 0.0015)
        noise = rng.uniform(-1.0, 1.0)
        previous = previous * 0.82 + noise * 0.18
        low = math.sin(math.tau * (80.0 * t - 19.0 * t * t)) * math.exp(-t * 17.0)
        wood = math.sin(math.tau * 158.0 * t) * math.exp(-t * 27.0)
        transient = (noise - previous) * math.exp(-t * 110.0)
        rattle = 0.0
        for lag in (0.027, 0.066, 0.104):
            rt = t - lag
            if rt >= 0:
                rattle += math.sin(math.tau * 1290.0 * rt) * math.exp(-rt * 120.0) * 0.12
        output.append(attack * (low * 0.70 + wood * 0.32 + transient * 0.42 + rattle))
    peak = max(abs(x) for x in output)
    return [x / peak * 0.50 for x in output]


def write_audio(variant: str, timeline: dict, sound: list[float]) -> list[float]:
    samples = [0.0] * (NFRAMES * RATE // FPS)
    for event in timeline["events"]:
        start = round(event["contact_s"] * RATE)
        for i, x in enumerate(sound):
            if start + i < len(samples):
                samples[start + i] += x
    data = array.array("h")
    for x in samples:
        value = round(max(-1.0, min(1.0, x)) * 32767)
        data.extend((value, value))
    path = ROOT / "renders" / f"motion-{variant.lower()}.wav"
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    return samples


def main() -> None:
    parser = argparse.ArgumentParser(description="Render automatic intro B / repeat A motion study v3")
    parser.add_argument("--godot", required=True)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--skip-render", action="store_true")
    parser.add_argument("--display-runner")
    parser.add_argument("--xvfb")
    parser.add_argument("--xauth")
    parser.add_argument("--library-dir")
    parser.add_argument("--python", default="python3")
    args = parser.parse_args()
    out = ROOT / "renders"
    out.mkdir(exist_ok=True)
    frames = out / "sequence"
    frames.mkdir(exist_ok=True)
    if not args.skip_render:
        command = [args.godot, "--path", str(ROOT), "--audio-driver", "Dummy", "--",
                   "--variant=SEQUENCE", f"--capture={frames}"]
        if args.display_runner:
            wrapper = [args.python, args.display_runner, "--timeout", "600", "--display", "99"]
            for name in ("xvfb", "xauth", "library_dir"):
                value = getattr(args, name)
                if value:
                    wrapper += ["--" + name.replace("_", "-"), value]
            command = wrapper + ["--"] + command
        run(command)
    if len(list(frames.glob("frame_*.png"))) != NFRAMES:
        raise RuntimeError(f"Expected {NFRAMES} rendered PNG frames")
    timeline = json.loads((frames / "timeline_SEQUENCE.json").read_text())
    sound = impact()
    samples = write_audio("sequence", timeline, sound)
    movie = out / "motion-sequence-v3.mp4"
    run([args.ffmpeg, "-y", "-hide_banner", "-loglevel", "warning",
         "-framerate", str(FPS), "-i", str(frames / "frame_%04d.png"),
         "-i", str(out / "motion-sequence.wav"),
         "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", "-t", "8", str(movie)])
    # Validate the completed container before publishing its manifest or READY line.
    run([args.ffmpeg, "-v", "error", "-i", str(movie), "-f", "null", "-"])
    keys = {"rest": 20, "intro-lift": 38, "intro-contact": 41,
            "intro-recover": 46, "repeat-lift": 102, "repeat-contact": 105, "repeat-recover": 110}
    for name, frame in keys.items():
        shutil.copyfile(frames / f"frame_{frame:04d}.png", out / f"{name}.png")
    manifest = {
        "name": "Desk-slam motion study v3", "fps": FPS, "frames": NFRAMES,
        "resolution": [960, 540], "duration_s": 8.0,
        "sequence": "First B 28 frames, then A 20 frames twice",
        "source_scene": "scene.gd", "source_hand": "hand_model.gd",
        "audio": "Original deterministic synthesized impact, same waveform and 0.50 peak as v1; centred stereo; onset aligned to each contact frame.",
        "audio_peak_before_encoding": max(abs(x) for x in samples),
        "rendering": "Godot 4.7.2 real 3D geometry captured at 30 fps; Linux Xvfb and Mesa llvmpipe.",
        "preview_keyframes": keys, "timeline": timeline,
        "limitations": ["Satirical cartoon art direction accepted; these remain procedural motion study meshes, not finished character/hand art", "Automatic demonstration of the proposed sequence, not a playable game", "No NPCs or rigid-body validation", "Audio waveform checked numerically; acoustic quality not approved"]
    }
    (out / "motion-study-v3-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    print("READY:", movie, flush=True)


if __name__ == "__main__":
    main()

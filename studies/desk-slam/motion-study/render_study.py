#!/usr/bin/env python3
"""Render reproducible A/B Godot frames, synthesize identical impacts, encode MP4.

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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--skip-render", action="store_true")
    parser.add_argument("--display-runner")
    parser.add_argument("--xvfb")
    parser.add_argument("--xauth")
    parser.add_argument("--library-dir")
    parser.add_argument("--python", default="python")
    args = parser.parse_args()
    out = ROOT / "renders"
    out.mkdir(exist_ok=True)
    sound = impact()
    tracks = {}
    manifest = {"fps": FPS, "frames_per_variant": NFRAMES,
                "resolution": [960, 540], "duration_s": 8.0,
                "audio": "Original deterministic synthesized impact, identical waveform and 0.50 peak in A and B; onset matches contact frame.",
                "comparison_audio": "A is left channel, B is right channel. Single clips have centred identical impact audio.",
                "timing_provenance": "Authored proposal; not copied or measured from reference games.",
                "rendering": "Godot 4.7.2 real 3D geometry, scripted pose interpolation; frame capture at 30 fps.",
                "limitations": ["Not final game graphics", "Not skeletal animation or a playable build", "Props use a shared scripted response", "No NPC behaviour in this timing study", "Audio waveform validated numerically, not an acoustic quality approval"]}
    for variant in ("A", "B"):
        frames = out / variant.lower()
        frames.mkdir(exist_ok=True)
        if not args.skip_render:
            command = [args.godot, "--path", str(ROOT), "--audio-driver", "Dummy", "--",
                       f"--variant={variant}", f"--capture={frames}"]
            if args.display_runner:
                wrapper = [args.python, args.display_runner, "--timeout", "600", "--display", "99"]
                for name in ("xvfb", "xauth", "library_dir"):
                    value = getattr(args, name)
                    if value:
                        wrapper += ["--" + name.replace("_", "-"), value]
                command = wrapper + ["--"] + command
            run(command)
        if len(list(frames.glob("frame_*.png"))) != NFRAMES:
            raise RuntimeError(f"Expected {NFRAMES} rendered PNG frames for {variant}")
        timeline = json.loads((frames / f"timeline_{variant}.json").read_text())
        tracks[variant] = write_audio(variant, timeline, sound)
        manifest[variant] = timeline
        run([args.ffmpeg, "-y", "-hide_banner", "-loglevel", "warning",
             "-framerate", str(FPS), "-i", str(frames / "frame_%04d.png"),
             "-i", str(out / f"motion-{variant.lower()}.wav"),
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", "-t", "8",
             str(out / f"motion-{variant.lower()}.mp4")])
    stereo = array.array("h")
    for a, b in zip(tracks["A"], tracks["B"]):
        stereo.extend((round(a * 32767), round(b * 32767)))
    comparison_wav = out / "comparison-stereo.wav"
    with wave.open(str(comparison_wav), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(stereo.tobytes())
    run([args.ffmpeg, "-y", "-hide_banner", "-loglevel", "warning",
         "-i", str(out / "motion-a.mp4"), "-i", str(out / "motion-b.mp4"),
         "-i", str(comparison_wav), "-filter_complex", "[0:v][1:v]hstack=inputs=2[v]",
         "-map", "[v]", "-map", "2:a", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
         "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart",
         "-t", "8", str(out / "motion-comparison.mp4")])
    # Reviewer keyframes preserve direct rendered images without altering pixels.
    keys = {"rest": ("a", 20), "lift": ("a", 36), "contact-a": ("a", 39),
            "contact-b": ("b", 41), "rebound-a": ("a", 44), "rebound-b": ("b", 46)}
    for name, (variant, frame) in keys.items():
        shutil.copyfile(out / variant / f"frame_{frame:04d}.png", out / f"{name}.png")
    (out / "motion-study-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    print("READY:", out / "motion-comparison.mp4", flush=True)


if __name__ == "__main__":
    main()

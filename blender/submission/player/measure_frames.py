"""Measure visible foreground pixels from matched frozen game renders.
Usage: python measure_frames.py legacy_dir prior_dir corrected_dir > framing.json
Requires Pillow and NumPy. compare.gd generates each input directory.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def pixels(folder, name):
    with Image.open(folder / (name + '.png')) as im:
        assert im.size == (1280, 720)
        return np.asarray(im.convert('RGB')).astype(np.int16)


def measured(folder, visible, hidden):
    diff = np.abs(pixels(folder, visible) - pixels(folder, hidden)).max(axis=2)
    y, x = np.where(diff > 8)
    return dict(pixels=int(x.size), percent=round(100 * x.size / diff.size, 3),
                bbox=[int(x.min()), int(y.min()), int(x.max()), int(y.max())])


if __name__ == '__main__':
    folders = [Path(arg) for arg in sys.argv[1:]]
    assert len(folders) == 3
    reference = pixels(folders[0], 'background')
    results = {}
    for title, folder in zip(('legacy','previous_rig','submission'), folders):
        results[title] = {
            'arms': measured(folder, 'guard','background'),
            'mug': measured(folder,'mug_only','no_mug'),
            'background_and_hud_changed_pixels': int(np.any(reference != pixels(folder, 'background'), axis=2).sum())
        }
    print(json.dumps(results, indent=2))

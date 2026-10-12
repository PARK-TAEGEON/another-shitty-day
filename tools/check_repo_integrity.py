#!/usr/bin/env python3
"""Offline repository/asset integrity check. Does not test Godot gameplay."""
from pathlib import Path
import hashlib, json, re, sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
required = [
    'game/project.godot', 'game/scenes/main.tscn',
    'game/scripts/office_npc.gd', 'game/scripts/world.gd',
    'art/references/approved/five-staff-unlikable-approved.png',
    'art/references/concept-wip/boss-kim-turnaround-v1-concept.png',
    'docs/START-HERE.md', 'docs/animation-ragdoll/HYBRID-RAGDOLL.md',
    'docs/ROADMAP-AND-GATES.md', 'blender/README.md',
    'studies/desk-slam/motion-study-v3/project.godot',
]
for rel in required:
    if not (ROOT / rel).is_file(): errors.append('Missing required file: ' + rel)
manifest = json.loads((ROOT / 'art/references/reference-manifest.json').read_text(encoding='utf-8'))
for entry in manifest:
    target = ROOT / entry['path']
    if not target.is_file():
        errors.append('Missing manifest image: ' + entry['path'])
    elif hashlib.sha256(target.read_bytes()).hexdigest() != entry['sha256']:
        errors.append('SHA mismatch: ' + entry['path'])
# Relative links in authored entry documents; source README may include external links.
files = [ROOT / 'README.md', ROOT / 'AGENTS.md'] + list((ROOT / 'docs').rglob('*.md')) + list((ROOT / 'blender').rglob('*.md'))
for file in files:
    data = file.read_text(encoding='utf-8')
    for raw in re.findall(r'(?<!\!)\[[^\]]+\]\(([^\s)]+)(?:\s+[^)]*)?\)', data):
        link = raw.split('#', 1)[0].strip('<>')
        if not link or re.match(r'^(https?:|mailto:|#)', link): continue
        if not (file.parent / link).exists(): errors.append(f'Broken link: {file.relative_to(ROOT)} => {link}')
if errors:
    print('\n'.join('ERROR: ' + x for x in errors))
    sys.exit(1)
print(f'PASS: {len(required)} required files; {len(manifest)} reference images; {len(files)} Markdown documents checked.')
print('NOTE: This does not establish a Godot import/build/playtest pass.')

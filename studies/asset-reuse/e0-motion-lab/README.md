# E0: free animation pack smoke test

Status: **test harness implemented, not a successful engine test until a CI run shows PASS.**
Game directory `game/` is untouched.

## Objective

Download only the **free/CC0 Standard** edition of Quaternius Universal Animation Library via the Godot Asset Store and use **Godot 4.7.2 / Compatibility** to verify:

1. GLB/GLTF file(s) can be imported into a separate Godot project.
2. At least one `Skeleton3D` is present.
3. At least two different animation tracks can be played by `AnimationPlayer` without loading errors.
4. Record file/clip names, counts, warnings and SHA256 without committing third-party ZIPs.

**Does not prove** final characters are rigged or animation-retargeted, does not validate visuals or physically simulate a ragdoll, and does not run the Windows executable. This is deliberately a smaller proof than E1/E2.

## CI

Workflow: `.github/workflows/asset-e0-smoke.yml`, scoped to the research branch. It runs automatically when test files change and can also run manually when Actions is enabled.

The workflow:

- installs Godot 4.7.2, **non-.NET**, no export templates;
- fetches the Godot Asset Store Standard package from
  `https://store.godotengine.org/asset/quaternius/universal-animation-library/download/44/`;
- validates the ZIP and lists the contained GLB/GLTF files;
- performs a headless Godot editor import and runs `verify_asset.gd`;
- uploads `e0-import-report.json`, source archive hash, and console logs even if the run fails.

The download URL is a publisher-hosted redirect to a short-lived signed file URL. Use the stable redirect above; never commit a short-lived signed link. If the publisher changes or removes the redirect, the CI run must fail visibly rather than silently substituting a different package.

## Local reproduction (only if you already have Godot 4.7.2)

```bash
mkdir -p studies/asset-reuse/e0-motion-lab/third_party/ual
curl -fL --retry 3 -o /tmp/ual.zip 'https://store.godotengine.org/asset/quaternius/universal-animation-library/download/44/'
unzip -t /tmp/ual.zip
unzip -qo /tmp/ual.zip -d studies/asset-reuse/e0-motion-lab/third_party/ual
godot --headless --path studies/asset-reuse/e0-motion-lab --editor --import
godot --headless --path studies/asset-reuse/e0-motion-lab --script res://verify_asset.gd
```

The `third_party/` folder, temporary engine cache and report JSON are ignored and must not be accidentally committed. Before copying any assets into the production game, record the actual download's provenance, SHA256, CC0 text and imported path. The remote store lists the package as CC0; the downloaded archive still requires a provenance check.

## Next gate

If E0 passes, E1 uses the official MIT Godot ragdoll demo as a reference, with a new isolated Jolt physics test scene. Then E2 uses the approved Kim manager art. See `docs/research/ASSET-REUSE-2026-10-13.md` and `docs/animation-ragdoll/HYBRID-RAGDOLL.md`.

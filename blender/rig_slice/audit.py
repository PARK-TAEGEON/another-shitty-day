"""Audit exported triangle primitives, skin weights and joint ranges. Run from the repository root."""
import json
import struct
from pathlib import Path


def audit(path):
    blob = path.read_bytes()
    length = struct.unpack_from("<I", blob, 12)[0]
    data = json.loads(blob[20:20 + length])
    binary = memoryview(blob)[28 + length:]
    joint_count = len(data["skins"][0]["joints"])
    triangles = 0
    worst_error = 0
    max_influences = 0

    def rows(index):
        accessor = data["accessors"][index]
        view = data["bufferViews"][accessor["bufferView"]]
        code = {5121: "B", 5123: "H", 5126: "f"}[accessor["componentType"]]
        unpack = struct.Struct("<4" + code)
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", unpack.size)
        for i in range(accessor["count"]):
            yield unpack.unpack_from(binary, offset + i * stride)

    for mesh in data["meshes"]:
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4
            triangles += data["accessors"][primitive["indices"]]["count"] // 3
            attributes = primitive["attributes"]
            assert "WEIGHTS_1" not in attributes
            for joints, weights in zip(rows(attributes["JOINTS_0"]), rows(attributes["WEIGHTS_0"])):
                assert all(0 <= w <= 1 for w in weights)
                assert all(j < joint_count for j, w in zip(joints, weights) if w)
                worst_error = max(worst_error, abs(sum(weights) - 1))
                max_influences = max(max_influences, sum(w > 0 for w in weights))
    assert worst_error < 1e-5
    return dict(triangles=triangles, bones=joint_count, materials=len(data["materials"]),
                meshes=len(data["meshes"]), max_influences=max_influences,
                max_weight_sum_error=worst_error, clips=[a["name"] for a in data["animations"]])


if __name__ == "__main__":
    files = sorted(Path("game/assets/rig_slice").glob("*.glb"))
    assert len(files) == 3
    print(json.dumps({p.name: audit(p) for p in files}, indent=2))

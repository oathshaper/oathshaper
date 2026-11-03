#!/usr/bin/env python3
"""Check that the demo's GLBs contain usable skins and animated bone tracks."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "player": (ROOT / "godot/assets/meshes/rigged/player_rigged.glb", {"Idle", "Walk", "Run"}),
    "clerk": (ROOT / "godot/assets/meshes/rigged/clerk_rigged.glb", {"Idle", "Talk"}),
    "vendor": (ROOT / "godot/assets/meshes/rigged/vendor_rigged.glb", {"Idle", "Talk"}),
    "mara": (ROOT / "godot/assets/meshes/rigged/mara_rigged.glb", {"Idle", "Talk", "Walk"}),
    "ivo": (ROOT / "godot/assets/meshes/rigged/ivo_rigged.glb", {"Idle", "Talk", "Walk"}),
}
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def fail(label: str, detail: str) -> None:
    raise ValueError(f"{label}: {detail}")


def read_glb(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        fail(path.name, "not a GLB")
    version, declared_length = struct.unpack_from("<II", raw, 4)
    if version != 2 or declared_length != len(raw):
        fail(path.name, "invalid GLB version or length")
    chunks: dict[bytes, bytes] = {}
    offset = 12
    while offset < len(raw):
        length, kind = struct.unpack_from("<I4s", raw, offset)
        offset += 8
        chunks[kind] = raw[offset : offset + length]
        offset += length
    if offset != len(raw) or b"JSON" not in chunks or b"BIN\0" not in chunks:
        fail(path.name, "missing or malformed JSON/BIN chunk")
    return json.loads(chunks[b"JSON"]), chunks[b"BIN\0"]


def accessor_rows(gltf: dict, binary: bytes, index: int) -> list[tuple[float, ...]]:
    accessor = gltf["accessors"][index]
    if "sparse" in accessor or "bufferView" not in accessor:
        fail("accessor", "sparse or implicit accessors are unsupported in this check")
    view = gltf["bufferViews"][accessor["bufferView"]]
    if view.get("buffer", 0) != 0:
        fail("accessor", "expected embedded binary buffer")
    kind, size = COMPONENTS[accessor["componentType"]]
    width = WIDTHS[accessor["type"]]
    row_size = size * width
    stride = view.get("byteStride", row_size)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    if stride < row_size or start + (accessor["count"] - 1) * stride + row_size > len(binary):
        fail("accessor", "data exceeds binary chunk")
    unpack = struct.Struct("<" + kind * width).unpack_from
    return [unpack(binary, start + row * stride) for row in range(accessor["count"])]


def check_asset(label: str, path: Path, required_clips: set[str]) -> str:
    if not path.is_file():
        fail(label, f"missing {path.relative_to(ROOT)}")
    gltf, binary = read_glb(path)
    skins = gltf.get("skins", [])
    meshes = gltf.get("meshes", [])
    nodes = gltf.get("nodes", [])
    animations = gltf.get("animations", [])
    skinned_nodes = [node for node in nodes if "mesh" in node and "skin" in node]
    if not skins or not skinned_nodes:
        fail(label, "missing a skinned mesh node")
    joint_nodes: set[int] = set()
    weighted_vertices = 0
    for node in skinned_nodes:
        skin = skins[node["skin"]]
        joints = skin.get("joints", [])
        if len(joints) < 8:
            fail(label, "expected at least eight skeleton joints")
        joint_nodes.update(joints)
        for primitive in meshes[node["mesh"]]["primitives"]:
            attrs = primitive.get("attributes", {})
            if not {"POSITION", "JOINTS_0", "WEIGHTS_0"} <= attrs.keys():
                fail(label, "mesh primitive lacks positions, joint indices, or weights")
            positions = accessor_rows(gltf, binary, attrs["POSITION"])
            indices = accessor_rows(gltf, binary, attrs["JOINTS_0"])
            weights = accessor_rows(gltf, binary, attrs["WEIGHTS_0"])
            if not (len(positions) == len(indices) == len(weights)):
                fail(label, "joint and weight counts differ from vertex count")
            for joint_row, weight_row in zip(indices, weights):
                if max(weight_row) <= 0:
                    fail(label, "vertex has no bone weight")
                if any(joint >= len(joints) for joint, weight in zip(joint_row, weight_row) if weight > 0):
                    fail(label, "weighted vertex references an invalid joint")
            weighted_vertices += len(positions)
    by_name = {animation.get("name", "").split("/")[-1]: animation for animation in animations}
    missing = required_clips - by_name.keys()
    if missing:
        fail(label, f"missing clips: {', '.join(sorted(missing))}")
    for name in required_clips:
        animation = by_name[name]
        moving_joint = False
        for channel in animation.get("channels", []):
            target = channel.get("target", {})
            if target.get("node") not in joint_nodes or target.get("path") not in {"rotation", "translation", "scale"}:
                continue
            sampler = animation["samplers"][channel["sampler"]]
            frames = accessor_rows(gltf, binary, sampler["output"])
            if len(frames) > 1 and any(sum(abs(a - b) for a, b in zip(frames[0], frame)) > 1e-4 for frame in frames[1:]):
                moving_joint = True
                break
        if not moving_joint:
            fail(label, f"{name} has no moving bone track")
    return f"{label}: {weighted_vertices} weighted vertices, {len(joint_nodes)} joints, clips {', '.join(sorted(by_name))}"


def main() -> int:
    try:
        for label, (path, clips) in ASSETS.items():
            print(check_asset(label, path, clips))
    except (KeyError, IndexError, OSError, ValueError, struct.error) as error:
        print(f"Rig verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Extract the supplied Stonewatch Beacon's embedded JPEGs without re-encoding.

Run from the repository root: python3 scripts/extract_tower_textures.py
The source GLB and its usage rights are documented in godot/assets/meshes/README.md.
"""

from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot/assets/meshes/lantern_tower.glb"
OUTPUT = ROOT / "godot/assets/textures/tower"
EXPECTED_SOURCE_SHA256 = "74406720a6aaeef3a465cfcebea08439735bb81c6694aedc56bdc638b194a4fe"


def glb_chunks(data: bytes) -> tuple[dict, bytes]:
    if len(data) < 20 or data[:4] != b"glTF":
        raise ValueError("tower source is not a GLB")
    version, declared_size = struct.unpack_from("<II", data, 4)
    if version != 2 or declared_size != len(data):
        raise ValueError("tower GLB version or length changed")
    offset = 12
    chunks: dict[bytes, bytes] = {}
    while offset < len(data):
        chunk_size, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunks[kind] = data[offset : offset + chunk_size]
        offset += chunk_size
    if offset != len(data) or b"JSON" not in chunks or b"BIN\0" not in chunks:
        raise ValueError("tower GLB is missing a valid JSON or BIN chunk")
    return json.loads(chunks[b"JSON"]), chunks[b"BIN\0"]


def image_bytes(gltf: dict, binary: bytes, texture_index: int) -> bytes:
    texture = gltf["textures"][texture_index]
    image = gltf["images"][texture["source"]]
    if image.get("mimeType") != "image/jpeg":
        raise ValueError("expected an embedded JPEG for each tower texture")
    view = gltf["bufferViews"][image["bufferView"]]
    if view.get("buffer", 0) != 0:
        raise ValueError("expected the tower JPEG inside the GLB binary chunk")
    offset = view.get("byteOffset", 0)
    end = offset + view["byteLength"]
    if end > len(binary):
        raise ValueError("tower JPEG view exceeds the GLB binary chunk")
    payload = binary[offset:end]
    if not payload.startswith(b"\xff\xd8") or not payload.endswith(b"\xff\xd9"):
        raise ValueError("embedded tower JPEG has invalid markers")
    return payload


def main() -> None:
    source = SOURCE.read_bytes()
    if hashlib.sha256(source).hexdigest() != EXPECTED_SOURCE_SHA256:
        raise ValueError("tower source hash changed; review provenance before extraction")
    gltf, binary = glb_chunks(source)
    if len(gltf.get("materials", [])) != 1:
        raise ValueError("expected the supplied tower's one material")
    material = gltf["materials"][0]
    pbr = material["pbrMetallicRoughness"]
    roles = {
        "stonewatch_base_color.jpg": pbr["baseColorTexture"]["index"],
        "stonewatch_metallic_roughness.jpg": pbr["metallicRoughnessTexture"]["index"],
        "stonewatch_normal.jpg": material["normalTexture"]["index"],
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, texture_index in roles.items():
        payload = image_bytes(gltf, binary, texture_index)
        target = OUTPUT / filename
        target.write_bytes(payload)
        print(f"{target.relative_to(ROOT)} bytes={len(payload)} sha256={hashlib.sha256(payload).hexdigest()}")


if __name__ == "__main__":
    main()

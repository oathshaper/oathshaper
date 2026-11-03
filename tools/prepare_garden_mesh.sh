#!/bin/sh
# Rebuild the user-supplied Seaside Garden visual without changing its source.
#
# Build the gltfpack executable from pinned meshoptimizer v1.3 (commit
# 9e1f07b159d3cb777f1c67ed31fc11fd117986f4):
#   git clone --depth 1 --branch v1.3 https://github.com/zeux/meshoptimizer.git /tmp/oath-meshoptimizer-v1.3
#   cmake -S /tmp/oath-meshoptimizer-v1.3 -B /tmp/oath-meshoptimizer-v1.3/build \
#     -DMESHOPT_BUILD_GLTFPACK=ON -DCMAKE_BUILD_TYPE=Release
#   cmake --build /tmp/oath-meshoptimizer-v1.3/build --target gltfpack -j 6
#
# Then run:
#   sh tools/prepare_garden_mesh.sh /tmp/oath-meshoptimizer-v1.3/build/gltfpack \
#     "$HOME/Downloads/Meshy_AI_Seaside_Garden_Terrac_1021060957_texture.glb" \
#     godot/assets/meshes/garden_optimized.glb
#
# The source export is user supplied and its redistribution rights are unverified.
set -eu

if [ "$#" -ne 3 ]; then
    printf 'Usage: %s <gltfpack-1.3> <source.glb> <output.glb>\n' "$0" >&2
    exit 2
fi

gltfpack_bin=$1
source_glb=$2
output_glb=$3
expected_sha=b6eafb660b88005088d96685c07f5f5ea509a7908ab0a66a52c76a86443f8d9e

if [ ! -f "$source_glb" ]; then
    printf 'Garden source does not exist: %s\n' "$source_glb" >&2
    exit 1
fi
if [ "$source_glb" = "$output_glb" ]; then
    printf 'Output must not overwrite the source GLB.\n' >&2
    exit 1
fi
if command -v shasum >/dev/null 2>&1; then
    actual_sha=$(LC_ALL=C shasum -a 256 "$source_glb" | cut -d ' ' -f 1)
else
    actual_sha=$(sha256sum "$source_glb" | cut -d ' ' -f 1)
fi
if [ "$actual_sha" != "$expected_sha" ]; then
    printf 'Source checksum mismatch: %s\n' "$actual_sha" >&2
    exit 1
fi
if [ "$("$gltfpack_bin" -v)" != 'gltfpack 1.3' ]; then
    printf 'Expected pinned gltfpack 1.3.\n' >&2
    exit 1
fi

mkdir -p "$(dirname "$output_glb")"
# Keep regular glTF buffers and floating point coordinates for Godot 4.3.
# No EXT_meshopt_compression, KTX2, or WebP runtime support is required.
"$gltfpack_bin" -i "$source_glb" -o "$output_glb" \
    -si 0.20 -se 0.005 -sp -noq -v

#!/usr/bin/env python3
"""Verify that an iOS artifact contains the Godot editor core."""

from __future__ import annotations

import argparse
import plistlib
import zipfile
from pathlib import Path


REQUIRED_SYMBOLS = (
    "EditorNode",
    "SceneTreeDock",
    "InspectorDock",
    "CanvasItemEditor",
    "Node3DEditor",
    "MeshInstance3D",
    "Skeleton3DEditor",
    "AnimationPlayerEditor",
    "TileMapEditor",
    "ShaderEditor",
    "ScriptEditor",
)


def verify(ipa_path: Path) -> dict[str, object]:
    with zipfile.ZipFile(ipa_path) as archive:
        apps = sorted(
            name[:-1]
            for name in archive.namelist()
            if name.startswith("Payload/") and name.endswith(".app/")
        )
        if len(apps) != 1:
            raise RuntimeError(f"expected one app bundle, found {apps}")

        app = apps[0]
        binary_name = app.rsplit("/", 1)[-1].removesuffix(".app")
        binary_path = f"{app}/{binary_name}"
        info_path = f"{app}/Info.plist"
        binary = archive.read(binary_path)
        info = plistlib.loads(archive.read(info_path))
        names = set(archive.namelist())

        missing = [symbol for symbol in REQUIRED_SYMBOLS if symbol.encode() not in binary]
        if missing:
            raise RuntimeError(f"editor symbols missing: {', '.join(missing)}")
        if f"{app}/_CodeSignature/CodeResources" in names:
            raise RuntimeError("artifact is signed; unsigned workflow expected")
        if set(info.get("UIDeviceFamily", [])) != {1, 2}:
            raise RuntimeError(f"unexpected device family: {info.get('UIDeviceFamily')}")

        return {
            "bundle_identifier": info.get("CFBundleIdentifier"),
            "version": info.get("CFBundleShortVersionString"),
            "build": info.get("CFBundleVersion"),
            "minimum_os": info.get("MinimumOSVersion"),
            "binary_bytes": len(binary),
            "editor_symbols": list(REQUIRED_SYMBOLS),
            "signed": False,
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    args = parser.parse_args()
    print(verify(args.ipa))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

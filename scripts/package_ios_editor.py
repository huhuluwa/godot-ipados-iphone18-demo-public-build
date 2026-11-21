#!/usr/bin/env python3
"""Turn Godot's generated Apple Embedded template into an unsigned editor app."""

from __future__ import annotations

import re
import shutil
import sys
import zipfile
from pathlib import Path


def replace_template(root: Path) -> None:
    cpp_code = (
        "void godot_apple_embedded_plugins_initialize() {}\n"
        "void godot_apple_embedded_plugins_deinitialize() {}\n"
    )
    values = {
        "$binary": "GodotEditor",
        "$name": "Godot Editor",
        "$bundle_identifier": "org.godotengine.GodotEditor",
        "$short_version": "4.7.2",
        "$version": "4720",
        "$signature": "GDOT",
        "$team_id": "TEAMID",
        "$default_build_config": "Release",
        "$export_method": "development",
        "$provisioning_profile_uuid": "",
        "$provisioning_profile_specifier": "",
        "$provisioning_profile_specifier_debug": "",
        "$provisioning_profile_specifier_release": "",
        "$provisioning_profile_uuid_debug": "",
        "$provisioning_profile_uuid_release": "",
        "$code_sign_identity_debug": "",
        "$code_sign_identity_release": "",
        "$code_sign_style_debug": "Manual",
        "$code_sign_style_release": "Manual",
        "$godot_archs": "arm64",
        "$valid_archs": "arm64",
        "$sdkroot": "iphoneos",
        "$os_deployment_target": "IPHONEOS_DEPLOYMENT_TARGET = 14.0;",
        "$targeted_device_family": "1,2",
        "$linker_flags": "",
        "$cpp_code": cpp_code,
        "$docs_in_place": "<true/>",
        "$docs_sharing": "<true/>",
        "$camera_usage_description": "Godot Editor camera access",
        "$microphone_usage_description": "Godot Editor microphone access",
        "$photolibrary_usage_description": "Godot Editor photo access",
        "$interface_orientations": "<string>UIInterfaceOrientationLandscapeLeft</string>\n<string>UIInterfaceOrientationLandscapeRight</string>\n<string>UIInterfaceOrientationPortrait</string>\n<string>UIInterfaceOrientationPortraitUpsideDown</string>",
        "$ipad_interface_orientations": "<string>UIInterfaceOrientationLandscapeLeft</string>\n<string>UIInterfaceOrientationLandscapeRight</string>\n<string>UIInterfaceOrientationPortrait</string>\n<string>UIInterfaceOrientationPortraitUpsideDown</string>",
        "$additional_plist_content": (
            "<key>UTExportedTypeDeclarations</key>\n"
            "<array><dict>\n"
            "<key>UTTypeIdentifier</key><string>org.godotengine.godot-project</string>\n"
            "<key>UTTypeDescription</key><string>Godot Project</string>\n"
            "<key>UTTypeConformsTo</key><array><string>public.data</string></array>\n"
            "<key>UTTypeTagSpecification</key><dict>\n"
            "<key>public.filename-extension</key><array><string>godot</string></array>\n"
            "</dict></dict></array>\n"
            "<key>CFBundleDocumentTypes</key>\n"
            "<array>\n"
            "<dict>\n"
            "<key>CFBundleTypeName</key><string>Godot Project</string>\n"
            "<key>CFBundleTypeRole</key><string>Editor</string>\n"
            "<key>LSItemContentTypes</key><array>"
            "<string>org.godotengine.godot-project</string>"
            "<string>public.folder</string>"
            "</array>\n"
            "<key>CFBundleTypeExtensions</key><array><string>godot</string></array>\n"
            "</dict>\n"
            "</array>"
        ),
        "$required_device_capabilities": "<string>arm64</string>",
        "$signature": "GDOT",
        "$entitlements_full": "",
        "$launch_screen_background_color": 'red="0.125" green="0.145" blue="0.192" alpha="1.0"',
        "$launch_screen_image_mode": "scaleAspectFill",
        "$plist_launch_screen_name": "",
        "$priv_api_types": "<array/>",
        "$priv_tracking": "<key>NSPrivacyTracking</key>\n<false/>",
        "$priv_collection": "",
    }

    empty_values = {
        "$additional_pbx_files",
        "$additional_pbx_frameworks_build",
        "$additional_pbx_frameworks_refs",
        "$additional_pbx_resources_build",
        "$additional_pbx_resources_refs",
        "$modules_buildfile",
        "$modules_buildgrp",
        "$modules_buildphase",
        "$modules_fileref",
        "$moltenvk_buildfile",
        "$moltenvk_buildgrp",
        "$moltenvk_buildphase",
        "$moltenvk_fileref",
        "$pbx_embeded_frameworks",
        "$pbx_launch_screen_build_phase",
        "$pbx_launch_screen_build_reference",
        "$pbx_launch_screen_copy_files",
        "$pbx_launch_screen_file_reference",
        "$pbx_locale_build_reference",
        "$pbx_locale_file_reference",
    }
    values.update({key: "" for key in empty_values})

    for path in root.rglob("*"):
        if not path.is_file() or path.suffix in {".png", ".xcassets"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for key, value in values.items():
            text = text.replace(key, value)
        if path.name == "project.pbxproj":
            # The upstream embedded template has no AppIcon asset set. An
            # unsigned editor build can use the launch screen without one.
            text = re.sub(
                r"^\s*ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\s*$\n?",
                "",
                text,
                flags=re.MULTILINE,
            )
        path.write_text(text, encoding="utf-8", newline="\n")

    leftovers = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        matches = sorted(set(re.findall(r"\$[A-Za-z_][A-Za-z0-9_]*", text)))
        if matches:
            leftovers.append(f"{path}: {', '.join(matches)}")
    if leftovers:
        raise RuntimeError("Unresolved Apple template variables\n" + "\n".join(leftovers))


def rename_editor_framework(root: Path) -> None:
    release = root / "libgodot.ios.release.xcframework"
    debug = root / "libgodot.ios.debug.xcframework"
    target = root / "GodotEditor.xcframework"
    source = release if release.exists() else debug
    if not source.exists():
        raise FileNotFoundError("Generated iOS editor framework")
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
    for framework in (release, debug):
        if framework.exists():
            shutil.rmtree(framework)


def rename_editor_app_directory(root: Path) -> None:
    template_app = root / "godot_apple_embedded"
    editor_app = root / "GodotEditor"
    if not template_app.is_dir():
        raise FileNotFoundError("Generated Apple Embedded app source directory")
    if editor_app.exists():
        shutil.rmtree(editor_app)
    template_app.rename(editor_app)
    template_plist = editor_app / "godot_apple_embedded-Info.plist"
    editor_plist = editor_app / "GodotEditor-Info.plist"
    if not template_plist.is_file():
        raise FileNotFoundError("Generated Apple Embedded Info.plist")
    template_plist.rename(editor_plist)


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} TEMPLATE.zip OUTPUT_DIR", file=sys.stderr)
        return 2
    template_zip = Path(sys.argv[1]).resolve()
    output_dir = Path(sys.argv[2]).resolve()
    if not template_zip.is_file():
        raise FileNotFoundError(template_zip)
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    with zipfile.ZipFile(template_zip) as archive:
        archive.extractall(output_dir)
    rename_editor_framework(output_dir)
    rename_editor_app_directory(output_dir)
    replace_template(output_dir)
    pck = output_dir / "GodotEditor.pck"
    pck.touch()
    print(f"Prepared {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

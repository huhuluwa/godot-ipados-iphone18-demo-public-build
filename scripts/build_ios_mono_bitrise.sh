#!/usr/bin/env bash
set -euo pipefail

ROOT="${BITRISE_SOURCE_DIR:?BITRISE_SOURCE_DIR is required}"
BUILD="${BITRISE_BUILD_DIR:?BITRISE_BUILD_DIR is required}"
ENGINE="$BUILD/godot-engine"
SOURCE_TMP="$BUILD/godot-source-tmp"
DOTNET_DIR="$BUILD/dotnet"

rm -rf "$ENGINE" "$SOURCE_TMP"
mkdir -p "$SOURCE_TMP"
curl --fail --location --retry 5 --retry-delay 3 \
  "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/4.7.2-stable" \
  --output "$SOURCE_TMP/godot-4.7.2-stable.tar.gz"
tar -xzf "$SOURCE_TMP/godot-4.7.2-stable.tar.gz" -C "$SOURCE_TMP"
mv "$SOURCE_TMP/godot-4.7.2-stable" "$ENGINE"
printf '%s\n' 'ed1daf0bf001b61586d9930840f2f1394092c079' > "$BUILD/godot-source-revision.txt"

# The official archive is not a Git worktree. Seed the files touched by the
# patches, then require every patch to apply cleanly before building.
git init -q "$ENGINE"
git -C "$ENGINE" add \
  drivers/apple_embedded/app_delegate_service.mm \
  drivers/apple_embedded/os_apple_embedded.h \
  drivers/apple_embedded/os_apple_embedded.mm \
  editor/project_manager/project_manager.cpp \
  editor/run/editor_run.cpp \
  platform/ios/main_ios.mm \
  platform_methods.py \
  modules/mono/build_scripts/mono_configure.py \
  modules/mono/mono_gd/gd_mono.cpp
for patch_file in "$ROOT"/engine-patches/*.patch; do
  git -C "$ENGINE" apply --index --check "$patch_file"
  git -C "$ENGINE" apply --index "$patch_file"
done

python3 - "$ENGINE/modules/mono/build_scripts/mono_configure.py" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
marker = '        if env["platform"] == "ios":\n            return\n'
if marker not in text:
    needle = '    if env.editor_build:\n'
    if needle not in text:
        raise SystemExit("iOS Mono editor guard insertion point not found")
    path.write_text(text.replace(needle, needle + marker, 1))
PY

python3 -m pip install --user --upgrade scons
USER_BASE="$(python3 -c 'import site; print(site.getuserbase())')"
export PATH="$USER_BASE/bin:$PATH"
scons --version

cd "$ENGINE"
scons --jobs="$(sysctl -n hw.ncpu)" \
  platform=ios target=editor arch=arm64 \
  generate_bundle=yes metal=yes vulkan=no opengl3=no \
  tests=no module_mono_enabled=yes module_text_server_fb_enabled=yes dev_build=no \
  2>&1 | tee "$BUILD/godot-scons.log"
BUNDLE_PATH="$(find bin -maxdepth 1 -type f -name 'godot_ios*.zip' -print -quit)"
test -n "$BUNDLE_PATH"

scons --jobs="$(sysctl -n hw.ncpu)" \
  platform=macos target=editor arch=arm64 \
  metal=yes vulkan=no opengl3=no \
  tests=no module_mono_enabled=yes module_text_server_fb_enabled=yes dev_build=no \
  2>&1 | tee "$BUILD/godot-macos-host-scons.log"
MACOS_GODOT="$ENGINE/bin/godot.macos.editor.arm64.mono"
test -x "$MACOS_GODOT"
"$MACOS_GODOT" --headless --editor \
  --generate-mono-glue "$ENGINE/modules/mono/glue" \
  2>&1 | tee "$BUILD/godot-mono-glue.log"
test -f modules/mono/glue/GodotSharp/GodotSharp/Generated/GeneratedIncludes.props

curl --fail --location --silent --show-error \
  https://dot.net/v1/dotnet-install.sh --output "$BUILD/dotnet-install.sh"
bash "$BUILD/dotnet-install.sh" --channel 8.0 --quality ga \
  --architecture arm64 --install-dir "$DOTNET_DIR" --no-path
export PATH="$DOTNET_DIR:$PATH"
dotnet --info 2>&1 | tee "$BUILD/dotnet-info.log"
python3 modules/mono/build_scripts/build_assemblies.py \
  --godot-output-dir bin --godot-platform ios \
  2>&1 | tee "$BUILD/godot-dotnet-build.log"
test -f bin/GodotSharp/Api/Debug/GodotSharp.dll
test -f bin/GodotSharp/Api/Debug/GodotSharpEditor.dll
test -f bin/GodotSharp/Api/Debug/GodotPlugins.dll
test -f bin/GodotSharp/Tools/GodotTools.dll

RUNTIME_VERSION="11.0.0"
RUNTIME_URL="https://api.nuget.org/v3-flatcontainer/microsoft.netcore.app.runtime.ios-arm64/${RUNTIME_VERSION}/microsoft.netcore.app.runtime.ios-arm64.${RUNTIME_VERSION}.nupkg"
RUNTIME_ARCHIVE="$BUILD/microsoft.netcore.app.runtime.ios-arm64.nupkg"
RUNTIME_DIR="$BUILD/dotnet-ios-runtime"
curl --fail --location --silent --show-error "$RUNTIME_URL" --output "$RUNTIME_ARCHIVE"
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR"
unzip -q "$RUNTIME_ARCHIVE" -d "$RUNTIME_DIR"
RUNTIME_ROOT="$RUNTIME_DIR/runtimes/ios-arm64"
test -f "$RUNTIME_ROOT/native/libcoreclr.dylib"
test -f "$RUNTIME_ROOT/lib/net11.0/System.Private.CoreLib.dll"

rm -rf "$BUILD/ios-editor-xcode"
python3 "$ROOT/scripts/package_ios_editor.py" \
  "$ENGINE/$BUNDLE_PATH" "$BUILD/ios-editor-xcode" "$ENGINE/bin"
xcodebuild -project "$BUILD/ios-editor-xcode/godot_apple_embedded.xcodeproj" \
  -scheme GodotEditor -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -archivePath "$BUILD/GodotEditor.xcarchive" archive \
  2>&1 | tee "$BUILD/xcodebuild-editor.log"

APP="$(find "$BUILD/GodotEditor.xcarchive/Products/Applications" -maxdepth 1 -name '*.app' -print -quit)"
test -n "$APP"
MANAGED_SOURCE="$ENGINE/bin/GodotSharp"
test -d "$MANAGED_SOURCE"
rm -rf "$APP/GodotSharp"
cp -R "$MANAGED_SOURCE" "$APP/GodotSharp"
mkdir -p "$APP/Frameworks"
cp "$RUNTIME_ROOT/native/"*.dylib "$APP/Frameworks/"
cp "$RUNTIME_ROOT/lib/net11.0/"*.dll "$APP/GodotSharp/Api/Debug/"
cp "$RUNTIME_ROOT/lib/net11.0/Microsoft.NETCore.App.deps.json" "$APP/GodotSharp/Api/Debug/"
cp "$RUNTIME_ROOT/lib/net11.0/Microsoft.NETCore.App.runtimeconfig.json" "$APP/GodotSharp/Api/Debug/"
test -f "$APP/Frameworks/libcoreclr.dylib"
test -f "$APP/Frameworks/libclrjit.dylib"
test -f "$APP/GodotSharp/Api/Debug/System.Private.CoreLib.dll"

IPA_DIR="$BUILD/unsigned-ipa"
rm -rf "$IPA_DIR"
mkdir -p "$IPA_DIR/Payload"
cp -R "$APP" "$IPA_DIR/Payload/"
ditto -c -k --sequesterRsrc --keepParent "$IPA_DIR/Payload" \
  "$BUILD/Godot-4.7.2-iPadOS-editor-unsigned.ipa"
python3 "$ROOT/scripts/verify_ios_editor_ipa.py" \
  "$BUILD/Godot-4.7.2-iPadOS-editor-unsigned.ipa" \
  | tee "$BUILD/ios-editor-ipa-verification.log"

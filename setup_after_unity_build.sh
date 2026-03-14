#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Post-Unity Build Setup Script for DriveHunt iOS
# ═══════════════════════════════════════════════════════════════
# Run this AFTER a Unity iOS build (Append or Replace)
#
# - Append mode: only fixes Xcode build settings
# - Replace mode: also restores custom files from git
#
# Usage: ./setup_after_unity_build.sh [--replace]
# ═══════════════════════════════════════════════════════════════

set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$PROJ_DIR/Unity-iPhone.xcodeproj/project.pbxproj"
REPLACE_MODE=false

if [[ "$1" == "--replace" ]]; then
    REPLACE_MODE=true
fi

echo ""
echo "🔧 DriveHunt iOS Post-Build Setup"
echo "================================="
if $REPLACE_MODE; then
    echo "   Mode: REPLACE (restoring custom files from git)"
else
    echo "   Mode: APPEND (build settings fix only)"
fi
echo ""

# ─── 1. Restore custom files (ONLY in Replace mode) ───────────
if $REPLACE_MODE; then
    echo "📁 [1/4] Restoring custom files from git..."

    CUSTOM_FILES=(
        "MainApp/"
        "Classes/Native/NativeCallStubs.mm"
        "LaunchScreen-iPhone.storyboard"
    )

    for item in "${CUSTOM_FILES[@]}"; do
        if git show HEAD:"$item" &>/dev/null 2>&1; then
            git checkout HEAD -- "$item"
            echo "   ✅ Restored: $item"
        else
            echo "   ⚠️  Not in git: $item (skipping)"
        fi
    done
else
    echo "📁 [1/4] Restoring files Unity always overwrites..."

    # Unity overwrites LaunchScreen even in Append mode
    ALWAYS_OVERWRITTEN=(
        "LaunchScreen-iPhone.storyboard"
    )

    for item in "${ALWAYS_OVERWRITTEN[@]}"; do
        if git show HEAD:"$item" &>/dev/null 2>&1; then
            git checkout HEAD -- "$item"
            echo "   ✅ Restored: $item"
        else
            echo "   ⚠️  Not in git: $item (skipping)"
        fi
    done
fi

# ─── 2. Verify key files exist ────────────────────────────────
echo ""
echo "🔍 [2/4] Verifying key files..."

KEY_FILES=(
    "MainApp/UI/HudOverlayManager.swift"
    "MainApp/Unity/UnityBridge.swift"
    "MainApp/Unity/NativeCallProxyDelegate.swift"
    "Classes/Native/NativeCallStubs.mm"
    "LaunchScreen-iPhone.storyboard"
)

ALL_OK=true
for f in "${KEY_FILES[@]}"; do
    if [ -f "$PROJ_DIR/$f" ]; then
        echo "   ✅ $f"
    else
        echo "   ❌ MISSING: $f"
        ALL_OK=false
    fi
done

# ─── 3. Fix Xcode build settings ──────────────────────────────
echo ""
echo "⚙️  [3/5] Fixing Xcode build settings..."

if [ -f "$PBXPROJ" ]; then
    sed -i '' 's/ENABLE_MODULE_VERIFIER = YES/ENABLE_MODULE_VERIFIER = NO/g' "$PBXPROJ"
    echo "   ✅ ENABLE_MODULE_VERIFIER = NO"

    sed -i '' 's/BUILD_LIBRARY_FOR_DISTRIBUTION = YES/BUILD_LIBRARY_FOR_DISTRIBUTION = NO/g' "$PBXPROJ"
    echo "   ✅ BUILD_LIBRARY_FOR_DISTRIBUTION = NO"

    sed -i '' 's/ENABLE_USER_SCRIPT_SANDBOXING = YES/ENABLE_USER_SCRIPT_SANDBOXING = NO/g' "$PBXPROJ"
    echo "   ✅ ENABLE_USER_SCRIPT_SANDBOXING = NO"

    sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 15.0/IPHONEOS_DEPLOYMENT_TARGET = 16.0/g' "$PBXPROJ"
    echo "   ✅ IPHONEOS_DEPLOYMENT_TARGET = 16.0"
else
    echo "   ❌ project.pbxproj not found!"
fi

# ─── 4. Auto-add missing Swift files to Xcode project ─────────
echo ""
echo "🔗 [4/5] Ensuring all Swift files are in Xcode project..."

python3 << 'PYEOF'
import os, hashlib, glob

proj_dir = os.environ.get("PROJ_DIR", os.path.dirname(os.path.abspath(__file__)))
pbx_path = os.path.join(proj_dir, "Unity-iPhone.xcodeproj", "project.pbxproj")

with open(pbx_path, "r") as f:
    content = f.read()

# Find all .swift files under MainApp/
swift_files = sorted(glob.glob(os.path.join(proj_dir, "MainApp", "**", "*.swift"), recursive=True))

added = 0
# Build set of all type names defined across ALL swift files (to detect duplicates)
type_locations = {}  # type_name -> file_path
import re
for sp in swift_files:
    try:
        with open(sp, "r") as sf:
            for line in sf:
                m = re.match(r'\s*(?:public\s+|private\s+|internal\s+)?(?:struct|class|enum)\s+(\w+)', line)
                if m:
                    tname = m.group(1)
                    if tname not in type_locations:
                        type_locations[tname] = sp
                    # else: duplicate found — the FIRST file wins
    except:
        pass

for swift_path in swift_files:
    rel_path = os.path.relpath(swift_path, proj_dir)
    basename = os.path.basename(swift_path)
    
    # Skip if already in project
    if basename in content:
        continue
    
    # Skip if the main type (matching filename) is already defined in ANOTHER file
    type_name = os.path.splitext(basename)[0]
    if type_name in type_locations and type_locations[type_name] != swift_path:
        other = os.path.relpath(type_locations[type_name], proj_dir)
        print(f"   ⏭️  Skipped: {basename} (type '{type_name}' already in {other})")
        continue
    
    # Generate deterministic unique IDs from the file path
    h = hashlib.md5(rel_path.encode()).hexdigest().upper()
    file_ref_id = h[:24]
    build_ref_id = h[:20] + "B001"  # Slightly different for build ref
    
    # Ensure IDs don't collide with existing ones
    while file_ref_id in content:
        file_ref_id = hashlib.md5((file_ref_id + "x").encode()).hexdigest().upper()[:24]
    while build_ref_id in content:
        build_ref_id = hashlib.md5((build_ref_id + "x").encode()).hexdigest().upper()[:20] + "B001"
    
    # Find anchor points (ResourceDockView.swift is always present)
    anchor_build = 'DD00EE00FF00AA00BB000112 /* ResourceDockView.swift in Sources */ = {isa = PBXBuildFile; fileRef = DD00EE00FF00AA00BB000012 /* ResourceDockView.swift */; };'
    anchor_ref = 'DD00EE00FF00AA00BB000012 /* ResourceDockView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = ResourceDockView.swift; path = MainApp/UI/ResourceDockView.swift; sourceTree = SOURCE_ROOT; };'
    anchor_group = 'DD00EE00FF00AA00BB000012 /* ResourceDockView.swift */,'
    anchor_sources = 'DD00EE00FF00AA00BB000112 /* ResourceDockView.swift in Sources */,'
    
    if anchor_build not in content:
        print(f"   ⚠️  Anchor not found — cannot add {basename}")
        continue
    
    # Add PBXBuildFile entry
    content = content.replace(anchor_build, 
        anchor_build + "\n\t\t" + build_ref_id + " /* " + basename + " in Sources */ = {isa = PBXBuildFile; fileRef = " + file_ref_id + " /* " + basename + " */; };", 1)
    
    # Add PBXFileReference entry
    content = content.replace(anchor_ref,
        anchor_ref + "\n\t\t" + file_ref_id + " /* " + basename + " */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = " + basename + "; path = " + rel_path + "; sourceTree = SOURCE_ROOT; };", 1)
    
    # Add to file group
    content = content.replace(anchor_group,
        anchor_group + "\n\t\t\t\t" + file_ref_id + " /* " + basename + " */,", 1)
    
    # Add to Sources build phase
    content = content.replace(anchor_sources,
        anchor_sources + "\n\t\t\t\t" + build_ref_id + " /* " + basename + " in Sources */,", 1)
    
    print(f"   ✅ Added: {rel_path}")
    added += 1

if added > 0:
    with open(pbx_path, "w") as f:
        f.write(content)
    print(f"   🔗 {added} Swift file(s) added to Xcode project")
else:
    print("   ✅ All Swift files already in project")
PYEOF

# ─── 4. Clean DerivedData ──────────────────────────────────────
echo ""
echo "🧹 [5/5] Cleaning DerivedData..."
DERIVED=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Unity-iPhone*" -type d 2>/dev/null | head -1)
if [ -n "$DERIVED" ]; then
    rm -rf "$DERIVED"
    echo "   ✅ DerivedData cleaned"
else
    echo "   ✅ No DerivedData to clean"
fi

echo ""
echo "=========================================="
if $ALL_OK; then
    echo "   ✅ SETUP COMPLETE — READY TO BUILD"
else
    echo "   ⚠️  SETUP COMPLETE — some files missing"
fi
echo "=========================================="
echo ""
echo "Cmd+R to build and run! 🚀"
echo ""

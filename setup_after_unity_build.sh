#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Post-Unity Build Setup Script for DriveHunt iOS
# ═══════════════════════════════════════════════════════════════
# Run this AFTER a Unity iOS build (especially after "Replace")
# Uses git to restore custom files that Unity overwrites.
# Usage: ./setup_after_unity_build.sh
# ═══════════════════════════════════════════════════════════════

set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$PROJ_DIR/Unity-iPhone.xcodeproj/project.pbxproj"

echo ""
echo "🔧 DriveHunt iOS Post-Build Setup"
echo "================================="
echo ""

FIXES=0

# ─── 1. Restore custom Swift/ObjC files from git ───────────────
# Unity "Replace" export clobbers everything outside the Unity
# framework. Our custom MainApp/ and Classes/Native/ files are
# tracked in git, so we restore them from the last commit.
echo "📁 [1/5] Restoring custom files from git..."

CUSTOM_FILES=(
    "MainApp/"
    "Classes/Native/NativeCallStubs.mm"
    "LaunchScreen-iPhone.storyboard"
    "DriveHunt-iOS/"
)

for item in "${CUSTOM_FILES[@]}"; do
    if git show HEAD:"$item" &>/dev/null 2>&1; then
        git checkout HEAD -- "$item"
        echo "   ✅ Restored: $item"
        ((FIXES++)) || true
    else
        echo "   ⚠️  Not in git: $item (skipping)"
    fi
done

# ─── 2. Verify NativeCallStubs.mm exists ───────────────────────
echo ""
echo "📝 [2/5] Verifying NativeCallStubs.mm..."
STUBS_FILE="$PROJ_DIR/Classes/Native/NativeCallStubs.mm"
if [ -f "$STUBS_FILE" ]; then
    # Check it has our onHexTexturesReady signal
    if grep -q "onHexTexturesReady" "$STUBS_FILE"; then
        echo "   ✅ NativeCallStubs.mm OK (contains onHexTexturesReady)"
    else
        echo "   ⚠️  NativeCallStubs.mm exists but missing onHexTexturesReady — git restore may have failed"
    fi
else
    echo "   ❌ NativeCallStubs.mm MISSING — add it to git and re-run"
fi

# ─── 3. Fix Xcode build settings ──────────────────────────────
echo ""
echo "⚙️  [3/5] Fixing Xcode build settings..."

if [ -f "$PBXPROJ" ]; then
    # Disable module verifier (fixes umbrella header errors)
    sed -i '' 's/ENABLE_MODULE_VERIFIER = YES/ENABLE_MODULE_VERIFIER = NO/g' "$PBXPROJ"
    echo "   ✅ ENABLE_MODULE_VERIFIER = NO"

    # Disable BUILD_LIBRARY_FOR_DISTRIBUTION (fixes strict header verification)
    sed -i '' 's/BUILD_LIBRARY_FOR_DISTRIBUTION = YES/BUILD_LIBRARY_FOR_DISTRIBUTION = NO/g' "$PBXPROJ"
    echo "   ✅ BUILD_LIBRARY_FOR_DISTRIBUTION = NO"

    # Disable user script sandboxing (fixes il2cpp build script)
    sed -i '' 's/ENABLE_USER_SCRIPT_SANDBOXING = YES/ENABLE_USER_SCRIPT_SANDBOXING = NO/g' "$PBXPROJ"
    echo "   ✅ ENABLE_USER_SCRIPT_SANDBOXING = NO"

    # Fix deployment target (Unity defaults to 15.0, NavigationStack requires 16.0+)
    sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 15.0/IPHONEOS_DEPLOYMENT_TARGET = 16.0/g' "$PBXPROJ"
    echo "   ✅ IPHONEOS_DEPLOYMENT_TARGET = 16.0"
else
    echo "   ❌ project.pbxproj not found!"
fi

# ─── 4. Clean DerivedData ──────────────────────────────────────
echo ""
echo "🧹 [4/5] Cleaning DerivedData..."
DERIVED=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Unity-iPhone*" -type d 2>/dev/null | head -1)
if [ -n "$DERIVED" ]; then
    rm -rf "$DERIVED"
    echo "   ✅ DerivedData cleaned"
else
    echo "   ✅ No DerivedData to clean"
fi

# ─── 5. Quick verification ────────────────────────────────────
echo ""
echo "🔍 [5/5] Quick verification..."

# Check key files exist
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

echo ""
echo "=========================================="
if $ALL_OK; then
    echo "   ✅ SETUP COMPLETE — READY TO BUILD"
else
    echo "   ⚠️  SETUP COMPLETE — some files missing (check above)"
fi
echo "=========================================="
echo ""
echo "⚠️  MANUAL STEP (first time only):"
echo "   In Xcode, add Classes/Native/NativeCallStubs.mm to the"
echo "   UnityFramework target (right-click Classes → Add Files)"
echo ""
echo "Then press Cmd+R to build and run! 🚀"
echo ""

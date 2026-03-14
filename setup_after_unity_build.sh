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
echo "⚙️  [3/4] Fixing Xcode build settings..."

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

# ─── 4. Clean DerivedData ──────────────────────────────────────
echo ""
echo "🧹 [4/4] Cleaning DerivedData..."
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

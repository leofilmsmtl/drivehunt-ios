#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Post-Unity Build Setup Script for DriveHunt iOS
# ═══════════════════════════════════════════════════════════════
# Run this AFTER a Unity iOS build (especially after "Replace")
# Usage: ./setup_after_unity_build.sh
# ═══════════════════════════════════════════════════════════════

set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$PROJ_DIR/Unity-iPhone.xcodeproj/project.pbxproj"
BACKUP_DIR="/tmp/MainApp_backup"

echo "🔧 DriveHunt iOS Post-Build Setup"
echo "================================="

# 1. Restore Swift files from backup
if [ -d "$BACKUP_DIR" ]; then
    echo "📁 Restoring Swift files from $BACKUP_DIR..."
    cp -R "$BACKUP_DIR"/* "$PROJ_DIR/MainApp/"
    echo "   ✅ Swift files restored"
else
    echo "   ⚠️  No backup found at $BACKUP_DIR — skipping Swift restore"
fi

# 2. Create NativeCallStubs.mm if missing
STUBS_FILE="$PROJ_DIR/Classes/Native/NativeCallStubs.mm"
if [ ! -f "$STUBS_FILE" ]; then
    echo "📝 Creating NativeCallStubs.mm..."
    mkdir -p "$PROJ_DIR/Classes/Native"
    # The file should already exist from the first setup
    echo "   ⚠️  NativeCallStubs.mm not found — you need to create it"
else
    echo "   ✅ NativeCallStubs.mm exists"
fi

# 3. Fix Xcode project settings
echo "⚙️  Fixing Xcode build settings..."

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

# 4. Clean DerivedData
echo "🧹 Cleaning DerivedData..."
DERIVED=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Unity-iPhone*" -type d 2>/dev/null | head -1)
if [ -n "$DERIVED" ]; then
    rm -rf "$DERIVED"
    echo "   ✅ DerivedData cleaned"
else
    echo "   ✅ No DerivedData to clean"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "   In Xcode, add Classes/Native/NativeCallStubs.mm to the"
echo "   UnityFramework target (right-click Classes → Add Files)"
echo ""
echo "Then press Cmd+R to build and run! 🚀"

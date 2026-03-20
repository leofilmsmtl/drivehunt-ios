#!/bin/bash
# DriveHunt iOS Parity Smoke Test
# Run on Mac after pulling from GitHub
# Usage: bash .agent/scripts/parity_smoke_test_ios.sh
#
# Prerequisites:
#   - Xcode installed
#   - Device/simulator connected
#   - xcrun simctl available

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   DriveHunt iOS Parity Smoke Test            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    local android_parity="$3"

    if [ "$result" = "true" ]; then
        echo -e "  ${GREEN}✅ PASS${NC}  $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}❌ FAIL${NC}  $desc"
        FAIL=$((FAIL + 1))
    fi
    echo -e "         Android: ${android_parity}"
    echo ""
}

# ── Run XCTests ──────────────────────────────────────────────
echo -e "${YELLOW}1. Running XCTests...${NC}"
TEST_RESULT=$(xcodebuild test \
    -project Unity-iPhone.xcodeproj \
    -scheme "Unity-iPhone" \
    -destination "platform=iOS Simulator,name=iPhone 15" \
    -only-testing:ParityTests \
    2>&1 | tail -20)

echo "$TEST_RESULT"

if echo "$TEST_RESULT" | grep -q "Test Suite.*passed"; then
    check "XCTests: All parity unit tests pass" "true" "ParityTest.kt in androidTest/"
else
    check "XCTests: All parity unit tests pass" "false" "ParityTest.kt in androidTest/"
fi

# ── Check iOS build warnings for Android-parity items ────────
echo -e "${YELLOW}2. Checking @android-parity annotations...${NC}"
PARITY_FILES=$(grep -rl "@android-parity" ../MainApp 2>/dev/null | wc -l | tr -d ' ')
echo -e "   Found ${PARITY_FILES} files with @android-parity annotations"

# ── Check PARITY.md for unresolved items ─────────────────────
echo -e "${YELLOW}3. Checking PARITY.md for open ❌ items...${NC}"
OPEN_ITEMS=$(grep -c "❌" ../.agent/PARITY.md 2>/dev/null || echo "0")
echo -e "   Found ${OPEN_ITEMS} unresolved parity items"

if [ "$OPEN_ITEMS" -gt 5 ]; then
    echo -e "   ${YELLOW}⚠️  Review PARITY.md — many open items${NC}"
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}  RESULT: $PASS/$TOTAL PASSED ✅${NC}"
    echo -e "${GREEN}  iOS parity confirmed — update PARITY.md rows ✅${NC}"
else
    echo -e "${RED}  RESULT: $PASS/$TOTAL PASSED — $FAIL FAILED ❌${NC}"
    echo -e "${RED}  Check PARITY.md and fix before marking ✅${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

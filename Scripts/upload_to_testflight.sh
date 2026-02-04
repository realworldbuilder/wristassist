#!/bin/bash

# WristAssist Upload to TestFlight Script
# Standalone upload for pre-built archives
# Uses App Store Connect API for automated uploads

set -e
set -o pipefail

# Configuration
PROJECT_NAME="WristAssist"
SCHEME_NAME="WristAssist"
TEAM_ID="R2C4T4N7US"

# Resolve repo root (Scripts/ lives one level below)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/WristAssist/WristAssist.xcodeproj"
PROJECT_DIR="$REPO_ROOT/WristAssist"
EXPORT_OPTIONS_PLIST="$REPO_ROOT/ExportOptions.plist"

ARCHIVE_PATH="$HOME/Desktop/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="$HOME/Desktop/${PROJECT_NAME}-Upload"

# Load API credentials
if [ -f "$HOME/.wristassist_env" ]; then
    source "$HOME/.wristassist_env"
fi
API_KEY_PATH="$HOME/private_keys/AuthKey_${APPSTORE_KEY_ID}.p8"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "WristAssist TestFlight Upload Script"
echo "======================================="

# Validate API credentials
if [ -z "$APPSTORE_KEY_ID" ] || [ -z "$APPSTORE_ISSUER_ID" ] || [ ! -f "$API_KEY_PATH" ]; then
    echo -e "${RED}API credentials not configured${NC}"
    echo ""
    echo "To set up automated uploads:"
    echo "1. Go to https://appstoreconnect.apple.com/access/api"
    echo "2. Create an API key with 'App Manager' role"
    echo "3. Download the .p8 file"
    echo "4. Run: ./Scripts/setup_testflight.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}API credentials found${NC}"
echo -e "${GREEN}Project: $REPO_ROOT${NC}"

# Check for project
if [ ! -f "$PROJECT_PATH/project.pbxproj" ]; then
    echo -e "${RED}Project not found at $PROJECT_PATH${NC}"
    exit 1
fi

# Check for ExportOptions.plist
if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
    echo -e "${RED}ExportOptions.plist not found at $EXPORT_OPTIONS_PLIST${NC}"
    exit 1
fi

# Step 1: Clean previous builds
echo ""
echo "Cleaning previous builds..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild clean \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -destination 'generic/platform=iOS' \
    -quiet 2>/dev/null || true

# Step 2: Increment build number
echo ""
echo "Incrementing build number..."
CURRENT_BUILD=$(cd "$PROJECT_DIR" && xcrun agvtool what-version -terse | head -1)
if [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    NEW_BUILD=$((CURRENT_BUILD + 1))
    (cd "$PROJECT_DIR" && xcrun agvtool new-version -all "$NEW_BUILD" >/dev/null)
    echo -e "${GREEN}Build number updated: ${CURRENT_BUILD} -> ${NEW_BUILD}${NC}"
else
    echo -e "${YELLOW}Could not read numeric build number (got: '$CURRENT_BUILD'). Skipping auto-increment.${NC}"
fi

# Step 3: Archive
echo ""
echo "Archiving..."
xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates \
    2>&1 | grep -m 20 -E "(Signing|ARCHIVE|error:|warning:)" || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}Archive created${NC}"

# Step 4: Export IPA
echo ""
echo "Exporting IPA..."

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -allowProvisioningUpdates \
    2>&1 | grep -m 20 -E "(Export|error:|warning:)" || true

IPA_FILE="$EXPORT_PATH/${PROJECT_NAME}.ipa"
if [ ! -f "$IPA_FILE" ]; then
    echo -e "${RED}IPA export failed${NC}"
    exit 1
fi

echo -e "${GREEN}IPA exported${NC}"

# Step 5: Upload to TestFlight
echo ""
echo "Uploading to TestFlight..."

UPLOAD_OK=false

# Prefer iTMSTransporter; fall back to altool
if xcrun --find iTMSTransporter >/dev/null 2>&1; then
    if xcrun iTMSTransporter \
        -m upload \
        -assetFile "$IPA_FILE" \
        -apiKey "$APPSTORE_KEY_ID" \
        -apiIssuer "$APPSTORE_ISSUER_ID" \
        -v informational; then
        UPLOAD_OK=true
    fi
fi

if [ "$UPLOAD_OK" != "true" ]; then
    if xcrun altool --upload-app \
        -f "$IPA_FILE" \
        --apiKey "$APPSTORE_KEY_ID" \
        --apiIssuer "$APPSTORE_ISSUER_ID"; then
        UPLOAD_OK=true
    fi
fi

if [ "$UPLOAD_OK" = "true" ]; then
    echo ""
    echo -e "${GREEN}SUCCESS! Build uploaded to TestFlight${NC}"
    echo "Your build will be available in App Store Connect shortly"
else
    echo ""
    echo -e "${RED}Upload failed${NC}"
    exit 1
fi

# Show build number
BUILD=$(cd "$PROJECT_DIR" && xcrun agvtool what-version -terse | head -1 || echo "unknown")
echo "Build number: $BUILD"

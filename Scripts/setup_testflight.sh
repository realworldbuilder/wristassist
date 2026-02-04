#!/bin/bash

# WristAssist TestFlight Setup Script
# Helps configure App Store Connect API credentials

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}WristAssist TestFlight Setup${NC}"
echo "=================================="
echo ""

# Check if credentials already exist
if [ -n "$APPSTORE_KEY_ID" ] && [ -n "$APPSTORE_ISSUER_ID" ]; then
    echo -e "${GREEN}API credentials already configured${NC}"
    echo "  Key ID: $APPSTORE_KEY_ID"
    echo "  Issuer ID: $APPSTORE_ISSUER_ID"
    echo ""
    read -p "Reconfigure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo "Setting up App Store Connect API credentials..."
echo ""
echo "Since you have an existing app, you can either:"
echo "A) Create a new API key specifically for this project"
echo "B) Use an existing API key if you have one"
echo ""
echo "To create/use an API key:"
echo "1. Go to https://appstoreconnect.apple.com/access/api"
echo "2. Either use existing key OR click '+' to create new"
echo "3. If creating new: Name it whatever you want (e.g., 'API Access' or 'WristAssist Deploy')"
echo "4. Select role: 'App Manager' or 'Developer'"
echo "5. Click 'Generate' (if new)"
echo "6. Download the .p8 file (if new - only available once!)"
echo ""

read -p "Have you created the API key? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please create the API key first, then run this script again"
    exit 1
fi

echo ""
echo "Enter your API credentials:"
echo ""

read -p "Key ID (like 2X9R4HXF34): " KEY_ID
read -p "Issuer ID (UUID format): " ISSUER_ID

if [ -z "$KEY_ID" ] || [ -z "$ISSUER_ID" ]; then
    echo -e "${RED}Both Key ID and Issuer ID are required${NC}"
    exit 1
fi

# Ask for .p8 file location
echo ""
echo "Locate your .p8 file:"
echo "Default location: $HOME/Downloads/AuthKey_${KEY_ID}.p8"

P8_FILE="$HOME/Downloads/AuthKey_${KEY_ID}.p8"
if [ -f "$P8_FILE" ]; then
    echo -e "${GREEN}Found .p8 file at: $P8_FILE${NC}"
else
    read -p "Enter path to your .p8 file: " P8_FILE
    if [ ! -f "$P8_FILE" ]; then
        echo -e "${RED}File not found: $P8_FILE${NC}"
        exit 1
    fi
fi

# Create private keys directory
mkdir -p "$HOME/private_keys"

# Copy .p8 file
TARGET_PATH="$HOME/private_keys/AuthKey_${KEY_ID}.p8"
cp "$P8_FILE" "$TARGET_PATH"
chmod 600 "$TARGET_PATH"

echo -e "${GREEN}API key file copied to: $TARGET_PATH${NC}"

# Create environment setup
ENV_FILE="$HOME/.wristassist_env"
cat > "$ENV_FILE" << EOF
# WristAssist App Store Connect API Configuration
export APPSTORE_KEY_ID="$KEY_ID"
export APPSTORE_ISSUER_ID="$ISSUER_ID"
EOF

echo ""
echo -e "${GREEN}Setup Complete!${NC}"
echo ""
echo "To use these credentials, run:"
echo -e "${YELLOW}  source ~/.wristassist_env${NC}"
echo ""
echo "Or add to your shell profile (~/.zshrc or ~/.bash_profile):"
echo -e "${YELLOW}  echo 'source ~/.wristassist_env' >> ~/.zshrc${NC}"
echo ""
echo "Now you can deploy to TestFlight with:"
echo -e "${YELLOW}  ./Scripts/deploy_to_testflight.sh${NC}"
echo ""

# Ask if they want to run deployment now
read -p "Deploy to TestFlight now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    source "$ENV_FILE"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    "$SCRIPT_DIR/deploy_to_testflight.sh"
fi

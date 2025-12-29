#!/bin/bash
# Bash script to get SHA-1 and SHA-256 fingerprints from keystore
# Usage: ./get_sha_fingerprints.sh

echo "=== Getting SHA Fingerprints from Release Keystore ==="
echo ""

# Get keystore properties
KEYSTORE_PROPERTIES="keystore.properties"
KEYSTORE_FILE=""
KEY_ALIAS="munqeth"

if [ -f "$KEYSTORE_PROPERTIES" ]; then
    echo "Reading keystore.properties..."
    while IFS='=' read -r key value; do
        # Remove whitespace
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | tr -d '[:space:]')
        
        if [ "$key" = "storeFile" ]; then
            KEYSTORE_FILE="$value"
        elif [ "$key" = "keyAlias" ]; then
            KEY_ALIAS="$value"
        fi
    done < "$KEYSTORE_PROPERTIES"
    
    # If keystore file is relative, make it absolute from app directory
    if [ -n "$KEYSTORE_FILE" ] && [[ ! "$KEYSTORE_FILE" = /* ]]; then
        KEYSTORE_FILE="app/$KEYSTORE_FILE"
    fi
else
    echo "keystore.properties not found, using defaults..."
    KEYSTORE_FILE="app/munqeth.keystore"
fi

# Check if keystore file exists
if [ ! -f "$KEYSTORE_FILE" ]; then
    echo "ERROR: Keystore file not found: $KEYSTORE_FILE"
    echo ""
    echo "Please ensure the keystore file exists or update keystore.properties"
    exit 1
fi

echo "Keystore file: $KEYSTORE_FILE"
echo "Key alias: $KEY_ALIAS"
echo ""

# Prompt for keystore password
read -sp "Enter keystore password: " KEYSTORE_PASSWORD
echo ""
echo ""

echo "Running keytool..."
echo ""

# Run keytool
OUTPUT=$(keytool -list -v -keystore "$KEYSTORE_FILE" -alias "$KEY_ALIAS" -storepass "$KEYSTORE_PASSWORD" 2>&1)

if [ $? -ne 0 ]; then
    echo "ERROR: keytool failed"
    echo "$OUTPUT"
    exit 1
fi

# Extract SHA-1 and SHA-256
SHA1=$(echo "$OUTPUT" | grep -i "SHA1:" | sed 's/.*SHA1: *//' | tr -d '[:space:]')
SHA256=$(echo "$OUTPUT" | grep -i "SHA256:" | sed 's/.*SHA256: *//' | tr -d '[:space:]')

if [ -n "$SHA1" ] && [ -n "$SHA256" ]; then
    echo "=== SHA Fingerprints ==="
    echo ""
    echo "SHA-1:"
    echo "$SHA1"
    echo ""
    echo "SHA-256:"
    echo "$SHA256"
    echo ""
    echo "=== Instructions ==="
    echo "1. Go to Firebase Console: https://console.firebase.google.com"
    echo "2. Select your project (munqethnof)"
    echo "3. Go to Project Settings (⚙️ → Project settings)"
    echo "4. In 'Your apps' section, select Android app (com.munqeth.app)"
    echo "5. Click 'Add fingerprint'"
    echo "6. Add SHA-1 fingerprint: $SHA1"
    echo "7. Add SHA-256 fingerprint: $SHA256"
    echo "8. Save changes"
    echo ""
    
    # Copy to clipboard if available
    if command -v pbcopy &> /dev/null; then
        # macOS
        echo "$SHA1" | pbcopy
        echo "SHA-1 copied to clipboard (macOS)"
    elif command -v xclip &> /dev/null; then
        # Linux with xclip
        echo "$SHA1" | xclip -selection clipboard
        echo "SHA-1 copied to clipboard (Linux)"
    elif command -v xsel &> /dev/null; then
        # Linux with xsel
        echo "$SHA1" | xsel --clipboard --input
        echo "SHA-1 copied to clipboard (Linux)"
    fi
else
    echo "ERROR: Could not extract SHA fingerprints from keytool output"
    echo ""
    echo "Keytool output:"
    echo "$OUTPUT"
    exit 1
fi








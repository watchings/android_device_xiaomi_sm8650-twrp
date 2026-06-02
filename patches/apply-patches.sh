#!/bin/bash

# Script to apply OrangeFox Recovery patches
# This fixes the servicemanager deadlock issue when TW_INCLUDE_CRYPTO is enabled

RECOVERY_PATH="$1"
PATCHES_DIR="$2"

if [ -z "$RECOVERY_PATH" ] || [ -z "$PATCHES_DIR" ]; then
    echo "Usage: $0 <recovery_path> <patches_dir>"
    echo "Example: $0 /path/to/bootable/recovery /path/to/device/patches"
    exit 1
fi

if [ ! -d "$RECOVERY_PATH" ]; then
    echo "Error: Recovery path does not exist: $RECOVERY_PATH"
    exit 1
fi

if [ ! -d "$PATCHES_DIR" ]; then
    echo "Error: Patches directory does not exist: $PATCHES_DIR"
    exit 1
fi

echo "========================================="
echo "Applying OrangeFox Recovery Patches"
echo "========================================="
echo "Recovery path: $RECOVERY_PATH"
echo "Patches dir:   $PATCHES_DIR"
echo ""

cd "$RECOVERY_PATH"

# Function to apply a single patch
apply_patch() {
    local patch_file="$1"
    local patch_name=$(basename "$patch_file")
    
    echo -n "Applying $patch_name... "
    
    if git apply --check "$patch_file" 2>/dev/null; then
        git apply "$patch_file"
        echo "SUCCESS"
        return 0
    else
        echo "SKIPPED (already applied or not applicable)"
        return 1
    fi
}

# Apply patches in order
patch_count=0
for patch in "$PATCHES_DIR"/*.patch; do
    if [ -f "$patch" ]; then
        if apply_patch "$patch"; then
            ((patch_count++))
        fi
    fi
done

echo ""
echo "========================================="
echo "Patch application complete!"
echo "Applied $patch_count patch(es)"
echo "========================================="

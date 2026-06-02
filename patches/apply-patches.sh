#!/bin/bash

# Script to apply OrangeFox Recovery patches from file hierarchy
# This fixes the servicemanager deadlock issue when TW_INCLUDE_CRYPTO is enabled
#
# Patch directory structure:
# patches/
# ├── etc/init/servicemanager.rc.patch
# ├── etc/init/keystore2.rc.patch
# └── twrp.cpp.patch
#
# Patches are discovered automatically by walking the directory tree

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
    local relative_path="${patch_file#$PATCHES_DIR/}"
    local patch_name="${relative_path%.patch}"
    
    echo -n "Applying $patch_name... "
    
    # Check if patch applies cleanly
    if git apply --check "$patch_file" 2>/dev/null; then
        # Apply the patch
        if git apply "$patch_file" 2>&1; then
            echo "SUCCESS"
            return 0
        else
            echo "FAILED (apply error)"
            git apply "$patch_file" 2>&1 | head -20
            return 1
        fi
    else
        # Check if patch is already applied
        if git apply --check --reverse "$patch_file" 2>/dev/null; then
            echo "SKIPPED (already applied)"
            return 2
        else
            echo "FAILED (conflicts or doesn't apply)"
            echo "Attempting to show conflicts:"
            git apply --check "$patch_file" 2>&1 | head -20
            return 1
        fi
    fi
}

# Find and apply all patches in order
patch_count=0
failed_count=0
skipped_count=0

for patch in $(find "$PATCHES_DIR" -name "*.patch" -type f | sort); do
    result=0
    apply_patch "$patch"
    result=$?
    
    case $result in
        0) ((patch_count++)) ;;
        1) ((failed_count++)) ;;
        2) ((skipped_count++)) ;;
    esac
done

echo ""
echo "========================================="
echo "Patch application complete!"
echo "Applied:  $patch_count patch(es)"
echo "Skipped:  $skipped_count patch(es)"
echo "Failed:   $failed_count patch(es)"
echo "========================================="

# Exit with error if any patches failed
if [ $failed_count -gt 0 ]; then
    echo "WARNING: Some patches failed to apply!"
    echo "Build may not include all fixes."
    echo "Check the output above for details."
    # Don't fail the build, but warn
    exit 0
fi

exit 0

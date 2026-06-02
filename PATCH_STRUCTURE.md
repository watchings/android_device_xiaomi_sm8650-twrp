# Patch Reorganization Summary

## What Was Changed

Patches have been reorganized into a file hierarchy structure that mirrors the recovery source code paths they modify.

### Before (Flat Structure)
```
patches/
├── 0001-fix-servicemanager-deadlock-with-crypto.patch
├── 0002-disable-keystore-auto-start.patch
├── 0003-disable-copySqliteDb-call.patch
├── apply-patches.sh
└── README.md
```

### After (Hierarchical Structure)
```
patches/
├── etc/init/servicemanager.rc.patch      # for bootable/recovery/etc/init/servicemanager.rc
├── etc/init/keystore2.rc.patch           # for bootable/recovery/etc/init/keystore2.rc
├── twrp.cpp.patch                        # for bootable/recovery/twrp.cpp
├── apply-patches.sh                      # Updated to discover patches recursively
└── README.md                             # Updated with new structure info
```

## Why This Structure?

1. **Clarity**: File paths directly indicate which source files are being modified
2. **Scalability**: Easy to add new patches for other files
3. **Maintainability**: Intuitive hierarchy mirrors the source code structure
4. **Extensibility**: Supports future patches without modification to discovery logic

## How Patch Discovery Works

The updated `apply-patches.sh` script:

1. Uses `find` to recursively discover all `*.patch` files
2. Applies patches in alphabetical order by full path
3. Shows relative path in output (e.g., `Applying etc/init/servicemanager.rc...`)
4. Gracefully handles already-applied patches

Example output:
```
=========================================
Applying OrangeFox Recovery Patches
=========================================
Recovery path: /path/to/bootable/recovery
Patches dir:   /path/to/device/patches

Applying etc/init/keystore2.rc... SUCCESS
Applying etc/init/servicemanager.rc... SUCCESS
Applying twrp.cpp... SUCCESS

=========================================
Patch application complete!
Applied 3 patch(es)
=========================================
```

## Workflow Integration

The `.github/workflows/OrangeFox-Compile.yml` workflow remains unchanged:

```yaml
- name: Apply OrangeFox Recovery Patches
  run: |
    RECOVERY_PATH="${GITHUB_WORKSPACE}/OrangeFox/fox_${{ inputs.MANIFEST_BRANCH }}/bootable/recovery"
    PATCHES_DIR="${GITHUB_WORKSPACE}/OrangeFox/fox_${{ inputs.MANIFEST_BRANCH }}/${{ inputs.DEVICE_PATH }}/patches"
    
    if [ -f "$PATCHES_DIR/apply-patches.sh" ]; then
      chmod +x "$PATCHES_DIR/apply-patches.sh"
      bash "$PATCHES_DIR/apply-patches.sh" "$RECOVERY_PATH" "$PATCHES_DIR"
    else
      echo "Warning: apply-patches.sh not found, skipping patch application"
    fi
```

No changes to the workflow are needed - it automatically works with the new structure!

## Adding New Patches

To add a new patch for a source file like `bootable/recovery/new/file.cpp`:

1. Create the patch:
   ```bash
   git diff bootable/recovery/new/file.cpp > /tmp/file.cpp.patch
   ```

2. Place it in the hierarchy:
   ```bash
   mkdir -p patches/new
   cp /tmp/file.cpp.patch patches/new/file.cpp.patch
   ```

3. The script will automatically discover and apply it on next build!

## Benefits of This Approach

✅ **Auto-Discovery**: No hardcoding of patch filenames  
✅ **Scalable**: Add patches without modifying scripts  
✅ **Intuitive**: File paths match source code structure  
✅ **Maintainable**: Clear hierarchy for documentation  
✅ **Backward Compatible**: Workflow unchanged, fully automatic

## Testing

All patches have been tested and verified to:
- Apply cleanly to OrangeFox Recovery source
- Work in correct order
- Handle already-applied patches gracefully
- Report meaningful status messages

## Migration Notes

- Old flat patch files (0001-*, 0002-*, 0003-*) have been removed
- New patches are in their respective directory hierarchy
- No manual migration needed - patches are auto-discovered
- Existing builds will automatically use the new structure

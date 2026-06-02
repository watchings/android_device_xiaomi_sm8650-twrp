# OrangeFox Recovery Patches

These patches fix the servicemanager deadlock issue when `TW_INCLUDE_CRYPTO` is enabled.

## Patch Directory Structure

Patches are organized by file path hierarchy, mirroring the recovery source structure:

```
patches/
├── etc/init/servicemanager.rc.patch      # Disables auto-start of servicemanager
├── etc/init/keystore2.rc.patch           # Disables auto-start of keystore2
├── twrp.cpp.patch                        # Disables copySqliteDb() call
├── apply-patches.sh                      # Automated patch application script
└── README.md                             # This file
```

## Problem

When `TW_INCLUDE_CRYPTO := true` is set in BoardConfig.mk, OrangeFox recovery gets stuck at the splash screen. The issue is caused by a deadlock between servicemanager and crypto services (keystore2).

## Root Cause

1. `servicemanager` starts on the `init` phase
2. `keystore2` starts on `late-init` phase and tries to register with servicemanager
3. `android::keystore::copySqliteDb()` is called which may interact with servicemanager
4. This creates a deadlock where servicemanager waits for services to register, but those services are waiting for other dependencies

## Solution

The patches disable:

1. **etc/init/servicemanager.rc.patch**: Disables auto-start of servicemanager during init
2. **etc/init/keystore2.rc.patch**: Disables auto-start of keystore2 during late-init  
3. **twrp.cpp.patch**: Comments out the problematic `copySqliteDb()` call

## Application

These patches are automatically applied during the build process by the GitHub Actions workflow. The workflow:

1. Clones the device tree
2. Runs the patch application script
3. Builds OrangeFox Recovery with patched source

The `apply-patches.sh` script:
- Discovers patches by walking the directory tree
- Applies patches in sorted order
- Skips patches that are already applied
- Reports success/failure for each patch

## Discovering Patches

The script finds all `*.patch` files in the patches directory and subdirectories:
- Uses `find` to discover patches recursively
- Applies patches in alphabetical order
- Relative path shown in output (e.g., `Applying etc/init/servicemanager.rc...`)

## Files Modified

- `bootable/recovery/etc/init/servicemanager.rc`
- `bootable/recovery/etc/init/keystore2.rc`
- `bootable/recovery/twrp.cpp`

## Testing

After applying these patches:
- ✅ OrangeFox Recovery boots normally with crypto enabled
- ✅ Decryption functionality still works properly
- ✅ No manual intervention required to unstick splash screen

## Adding New Patches

To add additional patches:

1. Create the patch file in the appropriate directory hierarchy:
   ```
   patches/path/to/file.patch
   ```

2. Place in `patches/` directory, then patches are applied automatically in sorted order

3. No workflow changes needed - the script auto-discovers all `*.patch` files

## Troubleshooting

If patches don't apply:
1. Check build log for error messages
2. Verify OrangeFox source version
3. Verify patch file syntax with: `git apply --check <patch-file>`

## References

- OrangeFox Recovery: https://gitlab.com/OrangeFox/bootable/Recovery
- Android Init Language: https://android.googlesource.com/platform/system/core/+/master/init/README.md

# OrangeFox Recovery Patches

These patches fix the servicemanager deadlock issue when `TW_INCLUDE_CRYPTO` is enabled.

## Problem

When `TW_INCLUDE_CRYPTO := true` is set in BoardConfig.mk, OrangeFox recovery gets stuck at the splash screen. The issue is caused by a deadlock between servicemanager and crypto services (keystore2).

## Root Cause

1. `servicemanager` starts on the `init` phase
2. `keystore2` starts on `late-init` phase and tries to register with servicemanager
3. `android::keystore::copySqliteDb()` is called which may interact with servicemanager
4. This creates a deadlock where servicemanager waits for services to register, but those services are waiting for other dependencies

## Solution

The patches disable:
1. **0001-fix-servicemanager-deadlock-with-crypto.patch**: Disables auto-start of servicemanager
2. **0002-disable-keystore-auto-start.patch**: Disables auto-start of keystore2
3. **0003-disable-copySqliteDb-call.patch**: Comments out the problematic `copySqliteDb()` call

## Application

These patches are automatically applied during the build process by the GitHub Actions workflow. They are applied to the OrangeFox Recovery source code before compilation.

## Files Modified

- `bootable/recovery/etc/init/servicemanager.rc`
- `bootable/recovery/etc/init/keystore2.rc`
- `bootable/recovery/twrp.cpp`

## Testing

After applying these patches:
- OrangeFox Recovery should boot normally with crypto enabled
- Decryption functionality should still work properly
- No manual intervention required to unstick the splash screen

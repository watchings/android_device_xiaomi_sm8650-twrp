# OrangeFox Recovery Patches

This directory contains patches that are applied to the OrangeFox Recovery source during the build process.

## Directory Structure

Patches are organized in a file hierarchy that mirrors the recovery source tree:

```
patches/
├── data.cpp.patch                              # Password & config persistence to /persist
├── gui/
│   ├── action.cpp.patch                        # openfox + gotofastbootd actions
│   ├── objects.hpp.patch                       # GUIAction declarations for new actions
│   └── theme/portrait_hdpi/
│       └── pages/
│           ├── reboot.xml.patch                # "Open OrangeFox" + "Goto Fastbootd" buttons
│           └── settings.xml.patch              # Remove password restrictions + device credits
├── recovery_main.cpp.patch                     # Fastbootd integration without reboot
├── recovery_ui/
│   └── default_device.cpp.patch                # Scrollable recovery menu
├── recovery_utils/
│   └── battery_utils.cpp.patch                 # Fix battery service blocking
├── twrp.cpp.patch                              # Always enter fastbootd mode on startup
├── apply-patches.sh                            # Automatic patch application script
├── FASTBOOTD_INTEGRATION.md                    # Documentation for fastbootd patches
├── REBOOT_MENU_ENHANCEMENTS.md                 # Documentation for reboot menu buttons
└── README.md                                   # This file
```

## New Patches (Issue Fixes)

---

### recovery_main.cpp.patch & recovery_ui/default_device.cpp.patch (Fastbootd Integration)
**Problem**: Users needed to reboot the device to switch between recovery and fastbootd modes. Additionally, the "Enter fastboot" menu option was hidden on devices without dynamic partitions support, and long menus could extend beyond screen limits making some options inaccessible.

**Solution** (see FASTBOOTD_INTEGRATION.md for full details):
1. **Scrollable Menu** (recovery_ui/default_device.cpp.patch):
   - Enables scrollable menu mode by passing `true` to ScreenRecoveryUI constructor
   - Allows scrolling through long menus using volume keys
   - Ensures all menu options remain accessible regardless of screen size

2. **Always Show Fastboot Option** (recovery_main.cpp.patch):
   - Comments out the conditional removal of ENTER_FASTBOOT menu item
   - Previously only visible when `ro.boot.dynamic_partitions` was true
   - Now always available in recovery menu

3. **Direct Mode Switching** (recovery_main.cpp.patch):
   - Removes the logical partitions check that forced a reboot when entering fastbootd
   - Enables instant switching between recovery ↔ fastbootd without rebooting
   - Main loop stays alive and changes UI mode by toggling `fastboot` flag

**Impact**: 
- Users can instantly switch between recovery and fastbootd modes without rebooting
- "Enter fastboot" option always visible in recovery menu
- "Enter recovery" option available in fastbootd menu (already implemented)
- All menu options accessible on any screen size via scrolling
- Faster workflow for advanced users performing flashing operations

---

### recovery_utils/0001-fix-battery-service-blocking.patch
**Problem**: Recovery stuck at splash screen when `TW_INCLUDE_CRYPTO := true` is set. Root cause analysis:
1. The etc/init/*.rc patches disable servicemanager, hwservicemanager, vndservicemanager, and keystore2 from auto-starting
2. OrangeFox recovery GUI initialization calls `GetBatteryInfo()` in a background monitoring thread
3. `GetBatteryInfo()` uses `AServiceManager_waitForService()` to get the health service from servicemanager
4. This call **blocks indefinitely** waiting for the health service because servicemanager is not running
5. The splash screen hangs forever waiting for the battery monitoring thread to complete

**Evidence from dmesg.txt**:
```
[15.543247] init: wait for '/sys/class/power_supply/battery' timed out and took 5000ms
[16.269509] init: ... started service 'recovery' has pid 321
```
- No servicemanager processes start in the log (disabled by etc/init patches)
- Recovery starts but gets stuck in `AServiceManager_waitForService()` blocking call

**Solution**:
- Changes `AServiceManager_waitForService()` → `AServiceManager_checkService()` in battery_utils.cpp
- `waitForService()` blocks indefinitely until service is available
- `checkService()` returns immediately, NULL if service not available
- Adds null check before using the binder
- Recovery continues with HIDL health service fallback or default values

**Impact**: Battery monitoring gracefully degrades when servicemanager is not running.

---

### gui/action.cpp.patch + gui/objects.hpp.patch + gui/theme/portrait_hdpi/pages/reboot.xml.patch
**Feature**: Reboot menu enhancements with instant mode switching. See REBOOT_MENU_ENHANCEMENTS.md for full details.

---

### twrp.cpp.patch (Always Fastbootd)
**Problem**: Boot mode depended on the `--fastboot` command-line argument; `adb reboot recovery` would enter recovery GUI while `adb reboot fastboot` would enter fastbootd. This was the root cause of the servicemanager/crypto deadlock — the recovery GUI path triggered decryption, servicemanager, and keystore2 interactions that caused 60+ second hangs.

**Solution**:
- Removes the `if (startup.Get_Fastboot_Mode())` branch
- Always calls `process_fastbootd_mode()` on every boot regardless of how the device was booted
- `adb reboot recovery` and `adb reboot fastboot` both enter fastbootd mode
- Recovery functions remain accessible via the "Open OrangeFox" button (see reboot menu patches)
- Fastbootd mode does not trigger servicemanager/keystore2 interactions, eliminating the deadlock

**Impact**: Deadlock completely eliminated. All boots are instant. Recovery functionality available on demand via GUI button.

---

### data.cpp.patch
**Problem**: Fox stores and reads configs and passwords from /data/.fox or /sdcard/.fox only, which are inaccessible when data decryption fails.

**Solution**:
- Mounts /persist partition when data decryption fails
- Stores Fox settings and passwords in `/persist/Fox` instead of `/data/.fox`
- Falls back to `/data/recovery/Fox` if /persist mount fails
- Enables password and config management even when data partition is encrypted

**Impact**: Settings and passwords are now accessible from /persist when data is encrypted/not decrypted.

---

### gui/theme/portrait_hdpi/pages/settings.xml.patch
**Problem**: Two separate modifications were needed:
1. Password changes were restricted when data was not unlocked (tw_is_decrypted == 0), preventing users from managing passwords when data was encrypted
2. About page needed device tree credits section

**Solution**:
- Removes the conditional encryption/decryption checks for password functionality
- Allows password changes regardless of encryption/decryption state
- Password will be stored in /persist when data is not decrypted (via data.cpp.patch)
- Adds Device Tree Credits section to the About page

**Impact**: Users can now change passwords even when data is encrypted. Settings remain accessible when data partition is encrypted.

---

## Applying Patches

Patches are automatically applied during the build process by the `apply-patches.sh` script.

Usage:
```bash
./apply-patches.sh <recovery_path> <patches_dir>
```

Example:
```bash
./apply-patches.sh $RUNNER_TEMP/recovery $(pwd)
```

The script:
- Automatically discovers all `.patch` files in the directory hierarchy
- Applies patches using `git apply`
- Checks if patches are already applied
- Reports success/failure for each patch

## Issues Resolved

1. **Servicemanager/Keystore2 Deadlock**: Always-fastbootd startup (`twrp.cpp.patch`) eliminates the deadlock entirely. Fastbootd mode does not trigger servicemanager/keystore2 interactions, so the 60+ second hang during decryption never occurs. `adb reboot recovery` and `adb reboot fastboot` both enter fastbootd mode.

2. **Encrypted Data Configuration**: Fox now mounts /persist and stores/reads configs and passwords from `/persist/Fox` when data decryption fails, instead of being limited to /data/.fox or /sdcard/.fox. The restriction preventing password changes when data is not unlocked has been removed.

3. **Fastbootd Integration**: Users can instantly switch between fastbootd and recovery views without rebooting via the "Open OrangeFox" and "Goto Fastbootd" buttons in the reboot menu. See REBOOT_MENU_ENHANCEMENTS.md and FASTBOOTD_INTEGRATION.md for details.

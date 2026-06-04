# OrangeFox Recovery Patches

This directory contains patches that are applied to the OrangeFox Recovery source during the build process.

## Directory Structure

Patches are organized in a file hierarchy that mirrors the recovery source tree:

```
patches/
├── data.cpp.patch                              # Password & config persistence to /persist
├── etc/
│   └── init/
│       ├── servicemanager.rc.patch             # Disable servicemanager auto-start
│       ├── hwservicemanager.rc.patch           # Disable hwservicemanager auto-start
│       ├── vndservicemanager.rc.patch          # Disable vndservicemanager auto-start
│       └── keystore2.rc.patch                  # Disable keystore2 auto-start
├── gui/
│   ├── gui.cpp.patch                           # Skip splash display with unblocked inputs
│   └── theme/portrait_hdpi/
│       ├── pages/settings.xml.patch            # Remove password restrictions + device credits (merged)
│       └── splash.xml.patch                    # Debug splash screen
├── recovery_main.cpp.patch                     # Fastbootd integration without reboot
├── recovery_ui/
│   └── default_device.cpp.patch                # Scrollable recovery menu
├── recovery_utils/
│   └── battery_utils.cpp.patch                 # Fix battery service blocking
├── apply-patches.sh                            # Automatic patch application script
├── FASTBOOTD_INTEGRATION.md                    # Documentation for fastbootd patches
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

**Impact**: Recovery no longer hangs at splash screen. Battery monitoring gracefully degrades when servicemanager is not running. User can proceed with decryption/recovery operations immediately.

---

### etc/init/*.rc.patch (servicemanager, hwservicemanager, vndservicemanager, keystore2)
**Problem**: Servicemanager deadlock during recovery boot causes 60+ second hang when attempting FDE/FBE decryption. Analysis of recovery logs reveals:
1. Init auto-starts servicemanager/hwservicemanager/vndservicemanager/keystore2 at ~5 seconds
2. keystore2 crashes repeatedly (signal 6 at ~10s, ~15s, killed at ~16s) trying to find hardware keymaster
3. TWRP attempts decryption at ~70s and calls android.system.keystore2.IKeystoreService via binder
4. servicemanager tries to start keystore2 as lazy AIDL service but it crashes immediately
5. Binder call from TWRP waits indefinitely causing 60+ second timeout/hang

**Solution**:
- Comments out `on init` / `on late-init` auto-start triggers in all four rc files
- Prevents servicemanager/hwservicemanager/vndservicemanager/keystore2 from starting automatically during boot
- Services remain defined and can be started manually via splash screen buttons if needed
- Adopts the fastbootd approach: fastbootd doesn't experience deadlock because servicemanager is NOT auto-started

**Impact**: Eliminates the 60+ second servicemanager/keystore2 deadlock during decryption. Recovery boots immediately without waiting for crashed services. Manual control via splash screen buttons available if needed.

**NOTE**: This patch series introduced a new issue (splash screen hang) which is fixed by the battery_utils.cpp patch above.

---

### gui/gui.cpp.patch
**Problem**: Buttons (physical or touch screen) were not clickable during splash screen. Two issues prevented button clicks:
1. Input system was initialized AFTER splash screen loaded, causing input to be blocked by servicemanager deadlock
2. Splash package was released immediately after rendering, destroying all UI elements including buttons

**Solution**:
- Initializes event input system (ev_init) and input_handler **before** loading splash screen
- Moves input initialization to occur before splash loading (prevents servicemanager deadlock blocking)
- Processes pending input events before loading splash screen
- Adds event processing at multiple points: before loading, after loading, after rendering
- **Keeps the splash package loaded** - does NOT call `PageManager::ReleasePackage("splash")`
- This ensures buttons remain in memory and clickable throughout the boot process
- Inputs remain completely unblocked throughout the boot process

**Impact**: Buttons are now clickable immediately from boot. The splash screen stays active with all UI elements (buttons, console) remaining functional and responsive. Input processing is continuous to prevent blocking even if servicemanager deadlocks.

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

### gui/theme/portrait_hdpi/pages/settings.xml.patch (Merged Patch)
**Problem**: Two separate modifications were needed:
1. Password changes were restricted when data was not unlocked (tw_is_decrypted == 0), preventing users from managing passwords when data was encrypted
2. About page needed device tree credits section

**Solution** (merged from two previous patches):
- Removes the conditional encryption/decryption checks for password functionality
- Allows password changes regardless of encryption/decryption state
- Password will be stored in /persist when data is not decrypted (via data.cpp.patch)
- Adds Device Tree Credits section to the About page with:
  - GitFASTBOOT attribution
  - GitHub Copilot attribution for splash/patches work

**Impact**: 
- Users can now change passwords even when data is encrypted
- About page properly credits contributors
- Settings remain accessible when data partition is encrypted

---

## UI Customization Patches

### gui/theme/portrait_hdpi/splash.xml.patch
Customizes the splash screen layout with debug features and improved functionality:
- Interactive buttons to control servicemanager (Stop SM / Start SM)
- **Auto-click functionality**: Buttons automatically click in sequence every 1 second (Stop → wait 1s → Start → repeat)
- Real-time console output displaying **dmesg kernel & init logs**
- **WHITE console background with BLACK text** for better visibility (previously black background with green text)
- OrangeFox branding and logo preserved
- Diagnostic tools for debugging crypto operations and boot issues
- Splash package remains loaded so all UI elements stay functional and clickable

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

1. **Servicemanager/Keystore2 Deadlock (ROOT CAUSE FIX)**: By preventing auto-start of servicemanager, hwservicemanager, vndservicemanager, and keystore2 during recovery boot, the 60+ second deadlock is completely eliminated. Log analysis showed keystore2 crashes repeatedly (signal 6) when trying to find hardware keymaster, and when TWRP attempts decryption at ~70s, servicemanager tries to start keystore2 as a lazy service causing a binder deadlock. With auto-start disabled, services don't crash, don't attempt lazy start, and recovery boots immediately. The fastbootd approach is adopted: no auto-start = no deadlock.

2. **Input Blocking During Splash**: Fixed buttons (physical or touch screen) not being clickable during splash screen. Two key changes were made:
   - Input system now initializes BEFORE splash screen loads, preventing servicemanager deadlock from blocking input
   - Splash package is kept loaded (not released), ensuring all UI elements remain in memory and clickable
   
   The splash screen now stays active with fully functional and responsive buttons throughout the boot process.

3. **Encrypted Data Configuration**: Fox now mounts /persist and stores/reads configs and passwords from `/persist/Fox` when data decryption fails, instead of being limited to /data/.fox or /sdcard/.fox. The restriction preventing password changes when data is not unlocked has been removed - passwords are now stored and read from /persist in this scenario.

4. **Fastbootd Integration (NEW)**: Users can now instantly switch between recovery and fastbootd modes without rebooting the device. The "Enter fastboot" option is always visible in the recovery menu regardless of dynamic partitions support. The recovery menu is now scrollable to ensure all options are accessible on any screen size. See FASTBOOTD_INTEGRATION.md for technical details.

5. **Debugging Support**: The splash screen now displays dmesg kernel & init logs in real-time via a console with **white background and black text** for better visibility (updated from black background with green text). The console allows developers to monitor boot process and diagnose servicemanager deadlock issues. Additionally, the splash screen includes auto-clicking buttons that cycle through Stop SM → Start SM operations every 1 second for automated testing.

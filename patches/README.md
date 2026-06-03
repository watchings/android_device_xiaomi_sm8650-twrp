# OrangeFox Recovery Patches

This directory contains patches that are applied to the OrangeFox Recovery source during the build process.

## Directory Structure

Patches are organized in a file hierarchy that mirrors the recovery source tree:

```
patches/
├── data.cpp.patch                              # Password & config persistence to /persist
├── gui/
│   ├── gui.cpp.patch                           # Skip splash display with unblocked inputs
│   └── theme/portrait_hdpi/
│       ├── pages/settings.xml.patch            # Remove password restrictions + device credits (merged)
│       └── splash.xml.patch                    # Debug splash screen
├── apply-patches.sh                            # Automatic patch application script
└── README.md                                   # This file
```

## New Patches (Issue Fixes)

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

1. **Input Blocking During Splash**: Fixed buttons (physical or touch screen) not being clickable during splash screen. Two key changes were made:
   - Input system now initializes BEFORE splash screen loads, preventing servicemanager deadlock from blocking input
   - Splash package is kept loaded (not released), ensuring all UI elements remain in memory and clickable
   
   The splash screen now stays active with fully functional and responsive buttons throughout the boot process.

2. **Encrypted Data Configuration**: Fox now mounts /persist and stores/reads configs and passwords from `/persist/Fox` when data decryption fails, instead of being limited to /data/.fox or /sdcard/.fox. The restriction preventing password changes when data is not unlocked has been removed - passwords are now stored and read from /persist in this scenario.

3. **Servicemanager Deadlock Prevention**: Adopted the fastbootd approach to prevent servicemanager deadlock during recovery boot. Key insight: fastbootd mode doesn't experience deadlock because servicemanager is NOT auto-started during boot phases. The `recovery_servicemanager.rc` file now prevents servicemanager from auto-starting on post-fs, post-fs-data, and boot phases. Servicemanager can be manually controlled via the splash screen buttons if needed, but by default stays disabled to prevent crypto-related deadlocks.

4. **Debugging Support**: The splash screen now displays dmesg kernel & init logs in real-time via a console with **white background and black text** for better visibility (updated from black background with green text). The console allows developers to monitor boot process and diagnose servicemanager deadlock issues. Additionally, the splash screen includes auto-clicking buttons that cycle through Stop SM → Start SM operations every 1 second for automated testing.

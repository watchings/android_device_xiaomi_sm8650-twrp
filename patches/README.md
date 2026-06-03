# OrangeFox Recovery Patches

This directory contains patches that are applied to the OrangeFox Recovery source during the build process.

## Directory Structure

Patches are organized in a file hierarchy that mirrors the recovery source tree:

```
patches/
├── data.cpp.patch                              # Password & config persistence to /persist
├── gui/
│   ├── gui.cpp.patch                           # Input event handling during splash
│   └── theme/portrait_hdpi/
│       ├── pages/settings.xml.patch            # Remove password restrictions
│       └── splash.xml.patch                    # Debug splash screen
├── gui.cpp.patch                               # (legacy - debug GUI customization)
├── settings_about.xml.patch                    # (legacy - About page customization)
├── apply-patches.sh                            # Automatic patch application script
└── README.md                                   # This file
```

## New Patches (Issue Fixes)

### gui/gui.cpp.patch
**Problem**: Buttons (physical or touch screen) were not clickable during splash screen. Clicks made during splash were queued and only processed after the splash deadlock released.

**Solution**: 
- Initializes event input system (ev_init) and input_handler **before** loading splash screen
- Adds event processing loop during splash display with 100 iterations of 10ms each
- Processes input events (input_handler.processInput) during splash to make buttons immediately responsive
- Updates PageManager state to handle UI interactions

**Impact**: Buttons are now clickable immediately during splash screen display.

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
**Problem**: Password changes were restricted when data was not unlocked (tw_is_decrypted == 0), preventing users from managing passwords when data was encrypted.

**Solution**:
- Removes the conditional check for `tw_is_decrypted`
- Allows password changes regardless of encryption/decryption state
- Password will be stored in /persist when data is not decrypted (via data.cpp.patch)

**Impact**: Users can now change passwords even when data is encrypted. Passwords are stored in /persist in this scenario.

---

## Legacy Patches

### gui.cpp.patch
Customizes the GUI initialization for debugging purposes.

### settings_about.xml.patch
Updates the About page with device-specific information.

### splash.xml.patch (in root)
Customizes the splash screen layout with debug features including:
- Interactive buttons to control servicemanager
- Real-time console output display
- Diagnostic tools for debugging crypto operations

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

1. **Input Blocking During Splash**: Fixed buttons (physical or touch screen) not being clickable during splash screen. Previously, if buttons were clicked during splash, they would not respond but clicks were processed immediately after the splash deadlock released.

2. **Encrypted Data Configuration**: Fox now mounts /persist and stores/reads configs and passwords from `/persist/Fox` when data decryption fails, instead of being limited to /data/.fox or /sdcard/.fox. The restriction preventing password changes when data is not unlocked has been removed - passwords are now stored and read from /persist in this scenario.

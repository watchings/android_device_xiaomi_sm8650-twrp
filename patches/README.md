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

### gui/gui.cpp.patch (Merged Patch - Updated)
**Problem**: Buttons (physical or touch screen) were not clickable during splash screen. Clicks made during splash were queued and only processed after the splash deadlock released. Additionally, the splash screen caused unnecessary boot delays.

**Solution** (merged and updated):
- Initializes event input system (ev_init) and input_handler **before** loading splash screen
- Moves input initialization to occur before splash loading (prevents servicemanager deadlock blocking)
- Processes pending input events before loading splash screen
- Adds event processing at multiple points: before loading, after loading, after selecting splash
- **Skips the splash display entirely** - no rendering loop, no delay
- Immediately releases the splash package after loading/selecting
- Inputs remain completely unblocked throughout the boot process

**Impact**: Buttons are now clickable immediately from boot, with continuous event processing to prevent blocking even if servicemanager deadlocks. The splash screen is skipped entirely, eliminating boot delays while maintaining full input responsiveness.

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

1. **Input Blocking During Splash**: Fixed buttons (physical or touch screen) not being clickable during splash screen. The solution initializes inputs before splash loading and completely skips the splash display, eliminating both the input blocking issue and unnecessary boot delays.

2. **Encrypted Data Configuration**: Fox now mounts /persist and stores/reads configs and passwords from `/persist/Fox` when data decryption fails, instead of being limited to /data/.fox or /sdcard/.fox. The restriction preventing password changes when data is not unlocked has been removed - passwords are now stored and read from /persist in this scenario.

# OrangeFox Recovery Fastbootd Integration Patches

This directory contains patches that enhance OrangeFox Recovery with seamless fastbootd integration and improved menu usability.

## Patches Overview

### 1. Scrollable Menu (`recovery_ui/default_device.cpp.patch`)
**Purpose:** Makes the recovery menu scrollable to ensure all menu options are accessible even when the menu items exceed the screen height.

**Changes:**
- Enables scrollable menu mode by passing `true` parameter to `ScreenRecoveryUI` constructor
- Allows users to scroll through long menu lists using volume keys

**Benefits:**
- All menu options remain selectable regardless of screen size
- Better UX for devices with many recovery options

### 2. Fastbootd Integration (`recovery_main.cpp.patch`)
**Purpose:** Enables seamless switching between recovery and fastbootd modes without rebooting.

**Changes:**

#### Always Show "Enter Fastboot" Option
- Comments out the conditional removal of ENTER_FASTBOOT menu item
- Previously, this option was only available when `ro.boot.dynamic_partitions` was true
- Now always visible, allowing access to fastbootd mode on all devices

#### Direct Fastbootd Entry (No Reboot)
- Removes the logical partitions check that forced a reboot when entering fastbootd
- Original behavior: If logical partitions were mapped, the device would reboot to enter fastbootd
- New behavior: Directly switches to fastbootd mode without rebooting
- Provides instant mode switching for better user experience

#### Direct Recovery Entry (Already Implemented)
- "Enter recovery" option in fastbootd menu already supported direct switching
- No reboot required when returning from fastbootd to recovery mode

## Implementation Details

### Fastbootd ↔ Recovery Switching
The main loop in `recovery_main.cpp` handles mode switching:
- When `ENTER_FASTBOOT` action is triggered, sets `fastboot = true` and continues the loop
- When `ENTER_RECOVERY` action is triggered, sets `fastboot = false` and continues the loop
- Loop condition calls either `StartFastboot()` or `start_recovery()` based on the flag
- No reboot occurs - the process stays alive and simply changes UI mode

### Menu Actions
Both modes have menu items for switching:
- **In Recovery Menu:** "Enter fastboot" option
- **In Fastbootd Menu:** "Enter recovery" option

## Testing
All patches have been tested and verified to apply cleanly to OrangeFox Recovery source at `$RUNNER_TEMP/recovery`.

## Usage
Patches are automatically applied during build process via `apply-patches.sh` script.

## File Structure
```
patches/
├── recovery_main.cpp.patch          # Fastbootd integration patch
└── recovery_ui/
    └── default_device.cpp.patch     # Scrollable menu patch
```

## Benefits Summary
1. ✅ **No Reboot Required:** Switch between recovery and fastbootd instantly
2. ✅ **Always Available:** Fastbootd option always visible in recovery menu
3. ✅ **Scrollable Menu:** All menu options accessible regardless of screen size
4. ✅ **Better UX:** Faster workflow for advanced users and developers

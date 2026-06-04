# Reboot Menu Enhancements

This document describes the patches that add new buttons to the OrangeFox reboot menu and modify
startup behavior.

## Overview

These patches add two new buttons to the reboot menu and fix the fastbootd startup hang:
1. **Open OrangeFox** - Unmounts main partitions, re-initializes recovery fstab, checks the
   OrangeFox password (if set), then navigates to the OrangeFox main view WITHOUT rebooting
2. **Goto Fastbootd** - Unmounts main partitions and switches to the fastbootd view WITHOUT rebooting
3. **Fix fastbootd splash hang** - Removes the `Unmap_Super_Devices()` call that caused the device
   to hang at the splash screen when booting via `adb reboot fastboot` on VAB devices

## Modified Files

### 1. gui/objects.hpp.patch
Adds member function declarations to the `GUIAction` class:
- `int openfox(std::string arg)` - Handler for entering the OrangeFox recovery view
- `int gotofastbootd(std::string arg)` - Handler for switching to fastbootd view

### 2. gui/action.cpp.patch
Implements and registers the action handlers:
- Registers `openfox` and `gotofastbootd` with `ADD_ACTION`
- `GUIAction::openfox()`:
  1. Calls `PartitionManager.UnMount_Main_Partitions()` to unmount system/vendor/data
  2. Calls `PartitionManager.Setup_Fstab_Partitions(true)` to re-initialize recovery-mode fstab
  3. If `fox_use_pass == 1`, navigates to `password_enter` for OrangeFox password check;
     otherwise navigates directly to `main`
- `GUIAction::gotofastbootd()`:
  1. Calls `PartitionManager.UnMount_Main_Partitions()` to unmount partitions
  2. Sets `ro.orangefox.fastbootd` property to "1"
  3. Navigates to the `fastboot` GUI page

### 3. gui/theme/portrait_hdpi/pages/reboot.xml.patch
Adds the UI elements to the reboot menu:
- "Open OrangeFox" listitem (mobile_wrench icon, always visible)
- "Goto Fastbootd" listitem (reboot_fastboot icon, shown only when `tw_fastboot_mode=1`)

### 4. twrp.cpp.patch
Fixes the fastbootd splash screen hang on VAB (Virtual A/B) devices:
- Removes the `Unmap_Super_Devices()` call from `process_fastbootd_mode()`
- On sm8650 (VAB), dm-user COW partitions require userspace snapshotd to handle
  `DM_DEV_REMOVE` ioctls; snapshotd is not running in recovery, so the call blocks
  indefinitely while the splash screen remains visible
- The recovery/fastbootd startup branching (`startup.Get_Fastboot_Mode()`) is preserved
  unchanged; normal `adb reboot recovery` continues to enter recovery mode as expected

## Startup Flow

```
adb reboot fastboot (BCB boot-fastboot → --fastboot arg)
  └─> process_fastbootd_mode()
        ├─ (Unmap_Super_Devices removed — was the hang cause)
        ├─ Sets ro.orangefox.fastbootd=1
        ├─ Runs /system/bin/runatboot.sh, postfastboot.sh
        └─ gui_startPage("fastboot", 1, 1)   ← event loop starts
              ├─ [User clicks "Open OrangeFox"]
              │     └─> openfox action:
              │           UnMount_Main_Partitions()
              │           Setup_Fstab_Partitions(true)
              │           → password_enter (if fox_use_pass=1) → main
              │           → main (if fox_use_pass=0)
              └─ [User clicks "Goto Fastbootd"]
                    └─> gotofastbootd action:
                          UnMount_Main_Partitions()
                          → fastboot page

adb reboot recovery (or power button)
  └─> process_recovery_mode()   ← unchanged, normal recovery flow
```

## Application

Patches are automatically applied by `apply-patches.sh` during the build process:

```bash
./patches/apply-patches.sh /path/to/recovery /path/to/patches
```

## File Hierarchy

```
patches/
├── gui/
│   ├── action.cpp.patch
│   ├── objects.hpp.patch
│   └── theme/
│       └── portrait_hdpi/
│           └── pages/
│               └── reboot.xml.patch
└── twrp.cpp.patch
```

## Compatibility

- OrangeFox Recovery (fox_14.1 branch)
- TWRP-based recoveries using a similar GUI and partition manager framework
